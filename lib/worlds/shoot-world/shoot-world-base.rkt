#lang racket
(require "../../basicWorldVisualization.rkt")
(require "../../baseWorldLogic.rkt")
(require "../../robotVisualization.rkt")
(require "../../helpers/canvas-edges.rkt")
(require "../../helpers/edge-helpers.rkt")
(require (prefix-in G-"../../geo/geo.rkt"))
(require (prefix-in R-"../../robot.rkt"))
(require 2htdp/image)
(provide
 run internal-make-robot set-world!
 get-#robot get-#shoot-robot get-all-edges
 set-motors! shoot angle-to-other-bot dist-to-other-bot
 set-radian-mode set-degree-mode get-cooldown-time
 get-looking-dist get-lookahead-dist get-lookbehind-dist num-balls-left
 front-left-close? front-right-close? back-left-close? back-right-close? relative-angle-of-other-bot
 angles-to-neutral-balls
 (struct-out world:shoot) (struct-out ball)
 get-world get-#robot ball-edges
 (rename-out [normalize-user-angle normalize-angle]))

(struct world:shoot (canvas edges robot1 robot2 [balls #:mutable]))
(struct ball (id pos vx vy type) #:mutable #:transparent)
(struct shoot-robot (robot on-tick lives balls-left last-fire name level og-image) #:mutable)
(define global-world (void))
(define (get-world) global-world)
(define (get-shoot-robot-1) (world:shoot-robot1 (get-world)))
(define (get-shoot-robot-2) (world:shoot-robot2 (get-world)))
(define (get-#shoot-robot n) (if (= n 1) (get-shoot-robot-1) (get-shoot-robot-2)))
(define (get-#robot n) (shoot-robot-robot (get-#shoot-robot n)))
(define robot#-on 0) ;; this is highly jenk, but fuck it
(define (get-robot) (get-#robot robot#-on))
(define (get-shoot-robot) (get-#shoot-robot robot#-on))
(define (get-other-robot)
  (if (equal? (get-#robot 1) (get-robot)) (get-#robot 2) (get-#robot 1)))

(define global-ball-id -1)
(define (get-ball-id)
  (set! global-ball-id (+ global-ball-id 1))
  global-ball-id)

(define tick# 0)
(define DEFAULT_BODY_COLOR "grey")
(define DEFAULT_WHEEL_COLOR "black")
(define WORLD_WIDTH 450)
(define WORLD_HEIGHT WORLD_WIDTH)
(define MAX_NUM_BALLS 5)
(define num-balls MAX_NUM_BALLS)
(define BALL_RADIUS 10)
(define GLOBAL_MAX_VX 50)
(define GLOBAL_MAX_VY GLOBAL_MAX_VX)
(define max-vx 50)
(define max-vy max-vx)
(define SECS_PER_TURN 5)
(define BALL_IMAGE_NEUT (circle BALL_RADIUS "solid" "black"))
(define BALL_IMAGE_1 (circle BALL_RADIUS "solid" "red"))
(define BALL_IMAGE_2 (circle BALL_RADIUS "solid" "green"))
(define disqualified? #f)
(define (make-mode-val normal-val advanced-val expert-val)
  (make-hash (list (cons 'normal normal-val) (cons 'advanced advanced-val) (cons 'expert expert-val))))
(define STARTING_BALLS (make-mode-val 5 3 1))
(define BALL_CAPACITY (make-mode-val 5 4 2))
(define STARTING_LIVES (make-mode-val 5 4 3))
(define angle-mode 'degrees)
(define COOLDOWN (make-mode-val 20 25 30))
(define (get-mode-val-level level mode-val)
  (hash-ref mode-val level))
(define (get-mode-val shoot-robot mode-val)
  (hash-ref mode-val (shoot-robot-level shoot-robot)))

(define (set-degree-mode) (set! angle-mode 'degrees))
(define (set-radian-mode) (set! angle-mode 'radians))

(define extra-image-space (* 4 BALL_RADIUS))
(define (set-to-og-image robot#)
  (define shoot-robot (get-#shoot-robot robot#))
  (define robot (shoot-robot-robot shoot-robot))
  (R-set-robot-image! robot (shoot-robot-og-image shoot-robot))
  )
(define (display-balls-of robot#)
  (define shoot-robot (get-#shoot-robot robot#))
  (define robot (shoot-robot-robot shoot-robot))
  (define robot-image (shoot-robot-og-image shoot-robot))
  (define num-balls (shoot-robot-balls-left shoot-robot))
  (define capacity (get-mode-val shoot-robot BALL_CAPACITY))
  (define spacing (/ (image-width robot-image) capacity))
  (define new-robot-image
    (foldl
      (lambda (x robot-image)
        (underlay/offset
          (ball-type->image robot#)
          (- x (/ (image-width robot-image) 2)) (* 0.5 (R-robot-width robot))
          ;;(- x (/ (image-width robot-image) 2)) (+ (* 0.5 (R-robot-width robot) BALL_RADIUS))
          robot-image))
      robot-image
      (map (lambda (i) (+ (* i spacing) (/ spacing 2))) (range (- capacity num-balls) capacity))))
  (R-set-robot-image! robot new-robot-image))

(define (edit-robot-image robot#)
  (define lives-left (shoot-robot-lives (get-#shoot-robot robot#)))
  (define start-lives (get-mode-val (get-#shoot-robot robot#) STARTING_LIVES))
  (define alpha-diff (floor (* (/ (- start-lives lives-left) (* 0.5 start-lives (+ 1 start-lives))) 255)))
  (define img (shoot-robot-og-image (get-#shoot-robot robot#)))
  (define color-list (image->color-list img))
  (define new-color-list
    (map
      (lambda (col)
        (match col 
          [(color red green blue alpha) 
          (color red green blue (inexact->exact (floor (max (- alpha alpha-diff) 0.0))))]))
      color-list))
  (set-shoot-robot-og-image! (get-#shoot-robot robot#) 
                             (color-list->bitmap new-color-list (image-width img) (image-height img))))

(define (internal-make-robot level name on-tick
                    #:image-url  [image-url  OPTIONAL_DEFAULT]
                    #:name-color [name-color OPTIONAL_DEFAULT]
                    #:name-font  [name-font  OPTIONAL_DEFAULT]
                    #:body-color  [body-color  DEFAULT_BODY_COLOR]
                    #:wheel-color [wheel-color DEFAULT_WHEEL_COLOR])
  (define robot-image
    (create-robot-img body-color wheel-color name
                      #:custom-name-color name-color
                      #:custom-name-font name-font
                      #:image-url image-url))
  (set! robot-image (overlay robot-image (rectangle (image-width robot-image) (+ extra-image-space (image-height robot-image))
   "solid" "transparent")))
  (define bot (simple-bot robot-image))
  ;(R-set-robot-angle! bot (/ pi 2))
  (shoot-robot 
    bot 
    on-tick 
    (get-mode-val-level level STARTING_LIVES)
    (get-mode-val-level level STARTING_BALLS)
    (- 0 (get-mode-val-level level COOLDOWN)) name level
    robot-image))

(define START_WIDTH .75)
(define START_HEIGHT .75)
(define (set-world! shoot-bot1 shoot-bot2)
  (cond
    [(equal? shoot-bot1 shoot-bot2)
     "Jacob... what do you think you're doing???????????"]
    [else
     (R-set-pos! (shoot-robot-robot shoot-bot1) (* -1/2 START_WIDTH WORLD_WIDTH) (* -1/2 START_HEIGHT WORLD_HEIGHT))
     (R-set-pos! (shoot-robot-robot shoot-bot2) (*  1/2 START_WIDTH WORLD_WIDTH) (*  1/2 START_HEIGHT WORLD_HEIGHT))
     (R-set-robot-angle! (shoot-robot-robot shoot-bot2) pi)
     (set!
      global-world
      (world:shoot
       (create-blank-canvas WORLD_WIDTH WORLD_HEIGHT)
       (get-edges WORLD_WIDTH WORLD_HEIGHT)
       shoot-bot1 shoot-bot2
       (list)))]))

(define (ball-edges ball)
  (get-edges (* BALL_RADIUS 2) (* BALL_RADIUS 2) #:shift-by (ball-pos ball)))
(define (update-ball-pos ball)
  (set-ball-pos!
   ball
   (G-add-points
    (ball-pos ball)
    (G-scale-point TICK_LENGTH (G-point (ball-vx ball) (ball-vy ball))))))
(define ball-k 0.01)
(define neutrelize-chance (make-mode-val 0.02 0.03 0.04))
(define (que-remove-ball id)
  (set! ball-ids-to-remove (cons id ball-ids-to-remove)))
(define (update-ball ball)
  (update-ball-pos ball)
  (cond
    [(and
      (number? (ball-type ball))
      (< (random) (get-mode-val (get-#shoot-robot (ball-type ball)) neutrelize-chance))) 
     (set-ball-type! ball 'neut)])
  (cond 
    [(maps-intersect? (ball-edges ball) (get-all-edges #:excluded-ball-types (list 'neut 1 2)))
     (define intersection-lls
       (first (maps-intersecting-lls (ball-edges ball) (get-all-edges #:excluded-ball-types (list 'neut 1 2)))))
     (define wall-angle (G-angle-of (cdr intersection-lls)))
     (define theta (* 2 wall-angle))
     (define vx (ball-vx ball))
     (define vy (ball-vy ball))
     (set-ball-vx! ball (+ (* vx (cos theta)) (* vy (sin theta))))
     (set-ball-vy! ball (- (* vx (sin theta)) (* vy (cos theta))))
     ]
    [else
     (set-ball-vx! ball (* (ball-vx ball) (- 1 ball-k)))
     (set-ball-vy! ball (* (ball-vy ball) (- 1 ball-k)))])
  (cond
    [(and (number? (ball-type ball))
          (maps-intersect? (robot-edges (get-#robot (- 3 (ball-type ball))))
                           (ball-edges ball)))
     (define robot# (- 3 (ball-type ball)))
     (define shoot-bot (get-#shoot-robot robot#))
     (set-shoot-robot-lives! shoot-bot (- (shoot-robot-lives shoot-bot) 1))
     (remove-ball (ball-id ball))
     (edit-robot-image robot#)
     (cond
      [(> (shoot-robot-lives shoot-bot) 0) 
        (teleport-bot# robot#)
        (display-balls-of robot#)]
      [else (set-to-og-image robot#)])
     ]
    [(symbol? (ball-type ball))
     (define (not-full? robot#)
       (define robot (get-#shoot-robot robot#))
       (< (shoot-robot-balls-left robot) (get-mode-val robot BALL_CAPACITY)))
     (define intersect-1? (and (not-full? 1) (maps-intersect? (robot-edges (get-#robot 1)) (ball-edges ball))))
     (define intersect-2? (and (not-full? 2) (maps-intersect? (robot-edges (get-#robot 2)) (ball-edges ball))))
     (cond
       [(or intersect-1? intersect-2?)
        (define robot# (if intersect-1? 1 2))
        (define robot (get-#shoot-robot robot#))
        (set-shoot-robot-balls-left!
         robot
         (+ (shoot-robot-balls-left robot) 1))
        (que-remove-ball (ball-id ball))
        (display-balls-of robot#)])]))

(define teleport_per 0.7)
(define (teleport-bot og-pos og-angle bot# #:tries [tries 10])
  (define edges (get-all-edges #:robot-edges-1? (= bot# 2)
                               #:robot-edges-2? (= bot# 1)))
  (define vert? (= (random 2) 0))
  (define pos? (= (random 2) 0))
  (define bot (get-#robot bot#))
  (define x-max (floor (* 1/2 teleport_per WORLD_WIDTH)))
  (define y-max (floor (* 1/2 teleport_per WORLD_HEIGHT)))
  (R-set-pos!
   bot
   (if vert? (double-randomized x-max) (* (if pos? 1 -1) x-max)) 
   (if vert? (* (if pos? 1 -1) y-max) (double-randomized y-max)))
  (R-set-robot-angle!
   bot
   (+ (if vert? 0 (/ pi 2)) (if pos? pi 0)))
  (cond
    [(maps-intersect? (robot-edges bot) edges)
     (cond
       [(> tries 1)
        (teleport-bot og-pos og-angle bot# #:tries (- tries 1))]
       [else
        (R-set-pos! bot (G-point-x og-pos) (G-point-y og-pos))
        (R-set-robot-angle! bot og-angle)])]))
(define (teleport-bot# bot#)
  (define bot (get-#robot bot#))
  (teleport-bot (R-robot-point bot) (R-robot-angle bot) bot#))

(define (get-all-edges #:excluded-ball-types [excluded-ball-types (list)]
                       #:robot-edges-1? [robot-edges-1? #f]
                       #:robot-edges-2? [robot-edges-2? #f])
  (define all-balls
    (filter
     (lambda (ball) (not (memv (ball-type ball) excluded-ball-types)))
     (world:shoot-balls global-world)))
  (define all-ball-edges (foldl append (list) (map ball-edges all-balls)))
  (define bot1-edges (if robot-edges-1? (robot-edges (get-#robot 1)) (list)))
  (define bot2-edges (if robot-edges-2? (robot-edges (get-#robot 2)) (list)))
  (append all-ball-edges bot1-edges bot2-edges (world:shoot-edges global-world)))

(define (remove-ball r-ball-id)
  (set-world:shoot-balls!
   (get-world)
   (filter (lambda (ball) (not (= (ball-id ball) r-ball-id)))
           (world:shoot-balls (get-world)))))

(define (ball-type->image ball-type)
  (match ball-type
   [1 BALL_IMAGE_1]
   [2 BALL_IMAGE_2]
   ['neut BALL_IMAGE_NEUT]))
(define (overlay-ball ball canvas)
  (overlay-image
   canvas (ball-type->image (ball-type ball))
   0 (ball-pos ball)))

(define force-fac 1.2)
(define (set-motors! left% right%)
  (R-set-inputs! (get-robot) (* left% force-fac) (* right% force-fac) #:max force-fac))
(define ball-vi 70)
(define (double-randomized n)
  (set! n (inexact->exact n))
  (random (- 0 n) n))
(define (get-cooldown-time)
  (max 0 (- (+ (get-mode-val (get-shoot-robot) COOLDOWN) (shoot-robot-last-fire (get-shoot-robot))) tick#)))
(define (add-random-ball)
  (define pos (G-point (double-randomized (floor (- (/ WORLD_WIDTH  2) BALL_RADIUS)))
                       (double-randomized (floor (- (/ WORLD_HEIGHT 2) BALL_RADIUS)))))
  (define type 'neut)
  (define shot-ball (ball (get-ball-id) pos 0 0 type))
  (add-ball shot-ball))
(define last-shot-tick 0)
(define idel-ticks-to-teleport 250)
(define (shoot)
  (cond
    [(and
      (> (shoot-robot-balls-left (get-shoot-robot)) 0)
      (= (get-cooldown-time) 0)
     (set-shoot-robot-balls-left!
      (get-shoot-robot)
      (- (shoot-robot-balls-left (get-shoot-robot)) 1)))
     (set! last-shot-tick tick#)
     (set-shoot-robot-last-fire! (get-shoot-robot) tick#)
     (define angle (R-robot-angle (get-robot)))
     (define r-pos (G-point (R-robot-x (get-robot)) (R-robot-y (get-robot))))
     (define type (if (equal? (get-robot) (get-#robot 1)) 1 2))
     (define robot-v (/ (+ (R-robot-vl (get-robot)) (R-robot-vr (get-robot))) 2))
     (define omega (/ (- (R-robot-vr (get-robot)) (R-robot-vl (get-robot)))
                      (R-robot-width (get-robot))))
     (define perp-v (* omega (R-robot-length (get-robot)) 0.5))
     (define pos
       (G-add-points r-pos
                     (G-rotate-point (G-point (* .5 (R-robot-length (get-robot))) 0) angle)))
     (define shot-ball (ball (get-ball-id) pos
                             (+ (* (+ ball-vi robot-v) (cos angle)) (* perp-v (cos (+ angle (/ pi 2)))))
                             (+ (* (+ ball-vi robot-v) (sin angle)) (* perp-v (sin (+ angle (/ pi 2)))))
                             type))
     (add-ball shot-ball)
     (display-balls-of robot#-on)]))
(define (add-ball ball)
  (set-world:shoot-balls!
      (get-world)
      (cons ball (world:shoot-balls (get-world)))))
(define (angle-to-other-bot)
  (define radians-angle
    (-
     (G-angle-between
       (R-robot-point (get-robot)) (R-robot-point (get-other-robot)))
     (R-robot-angle (get-robot))))
  (radians->user-angle (G-normalize-angle:rad radians-angle)))
(define (dist-to-other-bot)
  (G-dist
   (R-robot-point (get-robot)) (R-robot-point (get-other-robot))))
(define (relative-angle-of-other-bot)
  (radians->user-angle
    (G-normalize-angle:rad (- (R-robot-angle (get-other-robot)) (R-robot-angle (get-other-robot))))))

(define (normalize-user-angle user-angle)
  (if (equal? angle-mode 'radians)
      (G-normalize-angle:rad user-angle)
      (G-normalize-angle:deg user-angle)))

(define (radians->user-angle rad)
  (if (equal? angle-mode 'radians) rad (radians->degrees rad)))
(define (user-angle->radians user-angle)
  (if (equal? angle-mode 'radians) user-angle (degrees->radians user-angle)))

(define (get-looking-dist angle)
  (get-robot-map-dist (get-all-edges #:robot-edges-1? (= robot#-on 2) #:robot-edges-2? (= robot#-on 1))
                      (get-robot) (user-angle->radians angle)))
(define (get-lookahead-dist #:no-balls? [no-balls? #f])
  (- (get-looking-dist 0) (/ (R-robot-length (get-robot)) 2)))
(define (get-lookbehind-dist #:no-balls? [no-balls? #f])
  (- (get-looking-dist (radians->user-angle pi)) (/ (R-robot-length (get-robot)) 2)))
(define (corner-proximity front? left?)
  (define corner-pos (G-add-points (R-robot-point (get-robot))
                                   (G-rotate-point (G-point (* (if front? 0.5 -0.5) (R-robot-length (get-robot)))
                                                            (* (if left?  0.5 -0.5) (R-robot-width  (get-robot))))
                                                   (R-robot-angle (get-robot)))))
  (min (- (/ WORLD_WIDTH 2)  (abs (G-point-x corner-pos)))
       (- (/ WORLD_HEIGHT 2) (abs (G-point-y corner-pos)))))
(define close-threshold 15)
(define (front-left-close?)  (< (corner-proximity #t #t) close-threshold))
(define (front-right-close?) (< (corner-proximity #t #f) close-threshold))
(define (back-left-close?)   (< (corner-proximity #f #t) close-threshold))
(define (back-right-close?)  (< (corner-proximity #f #f) close-threshold))
(define (angles-to-neutral-balls)
  (map
   (lambda (ball) 
    (radians->user-angle (G-normalize-angle:rad (- (G-angle-between (R-robot-point (get-robot)) (ball-pos ball)) 
                                                   (R-robot-angle (get-robot))))))
   (filter
    (lambda (ball) (equal? (ball-type ball) 'neut))
    (world:shoot-balls (get-world)))))
(define (num-balls-left)
  (shoot-robot-balls-left (get-shoot-robot)))
  

(define ticks-per-new-ball 500)
(define printing-interval 35)
(define ball-ids-to-remove (list))
(create-run-function
 internal-run
 [(set! tick# 0)
  (define (edges-1)
    (get-all-edges #:excluded-ball-types (list 'neut 1 2) #:robot-edges-2? #t))
  (define (edges-2)
    (get-all-edges #:excluded-ball-types (list 'neut 1 2) #:robot-edges-1? #t))
  (define walls
    (get-all-edges #:excluded-ball-types (list 'neut 1 2)))
  (display-balls-of 1)
  (display-balls-of 2)]
 (lambda (world)
   (define tick-start 0); (current-milliseconds))
   (define print? (= (modulo tick# printing-interval) 10))
   (define (reset-start) 0); (set! tick-start (current-milliseconds)))
   (define (print-time-diff name)
     (cond
       [true 0]
       [print? (printf "~a diff:~s~n" name (- (current-milliseconds) tick-start))
               (reset-start)]))
   (cond
     [(= (random ticks-per-new-ball) 0) (add-random-ball)])
   (reset-start)
   (define k 1.4)
   (move-bot (get-#robot 1) k #:edges walls)
   (move-bot (get-#robot 2) k #:edges walls)
   (print-time-diff "move bot")
   (map update-ball (world:shoot-balls (get-world)))
   (print-time-diff "ball update")
   (set! robot#-on 1)
   ((shoot-robot-on-tick (world:shoot-robot1 (get-world))) tick#)
   (set! robot#-on 2)
   ((shoot-robot-on-tick (world:shoot-robot2 (get-world))) tick#)
   (print-time-diff "on-tick")
   (set! tick# (+ tick# 1))
   (cond
    [(> tick# (+ last-shot-tick idel-ticks-to-teleport))
      (teleport-bot# 1)
      (teleport-bot# 2)
      (set! last-shot-tick tick#)])
   (define img
     (overlay-robot
      (overlay-robot
       (foldl
        overlay-ball
        (world:shoot-canvas world)
        (world:shoot-balls world))
       (get-#robot 1))
      (get-#robot 2)))
   (print-time-diff "image-display")
   (for-each remove-ball ball-ids-to-remove)
   (set! ball-ids-to-remove (list))
   img)
 get-world
 [] []
 (lambda (world)
   (or (= (shoot-robot-lives (get-#shoot-robot 1)) 0)
       (= (shoot-robot-lives (get-#shoot-robot 2)) 0)))
 [(define r1? (= (shoot-robot-lives (get-#shoot-robot 1)) 0))
  (define r2? (= (shoot-robot-lives (get-#shoot-robot 2)) 0))
  (cond
    [(or r1? r2?) 
    (define bot (get-#shoot-robot (if r1? 2 1)))
    (printf "With ~s of ~s lives left, ~a wins!~n"
    (shoot-robot-lives bot) (get-mode-val bot STARTING_LIVES) (shoot-robot-name bot))]
    [else (printf ":(~n")])])
(define-syntax-rule (run) (internal-run (lambda (_) (void))))