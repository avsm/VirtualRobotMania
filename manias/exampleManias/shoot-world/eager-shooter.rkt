#lang racket
(require "../../../lib/worlds/shoot-world/shoot-world.rkt")
(provide eager-shooter)


(define p 2)
(define neut-ball-p 1)
(define (on-tick tick#)
  (set-radian-mode) ;; make sure to have this line in on-tick
  (define angle (angle-to-other-bot))
  (cond
    [(front-left-close?)  (set-motors! -1 -0.3)]
    [(front-right-close?) (set-motors! -0.3 -1)]
    [(back-left-close?)  (set-motors! 1 0.3)]
    [(back-right-close?) (set-motors! 0.3 1)]
    [(= (num-balls-left) 0)
     (define angles (angles-to-neutral-balls))
     (cond
      [(empty? angles) (set-motors! 0 0)]
      [else
        (define goal-angle 
            (foldl (lambda (a1 a2) (if (> (get-looking-dist a1) (get-looking-dist a2)) a2 a1))
                    (first angles) (rest angles)))
        (set-motors! (- 1 (* neut-ball-p goal-angle)) (+ 1 (* neut-ball-p goal-angle)))])]
    [(= (modulo tick# 50) 0) (set! p (+ (/ (random) 4) 1.35))]
    [else 
    (set-motors! (- 1 (* p angle)) (+ 1 (* p angle)))] 
    )
  (cond
   [(or (< (abs angle) 0.35) (and (< (abs angle) 0.6) (< (dist-to-other-bot) 175)))
     (shoot)])
  )


(define eager-shooter
  (make-robot
   "Eager Shooter" on-tick
   #:body-color "orange"
   #:wheel-color "red"
   #:image-url "https://www.netclipart.com/pp/m/44-448829_eager-cartoon.png"
   ))