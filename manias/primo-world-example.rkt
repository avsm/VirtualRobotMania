#lang racket
(require "../lib/worlds/primo-world.rkt")

;; The width of the field is 700 and the height is 500
;; STUFF TO TRY
;; (set-motors! left% right%) -> set's torque on wheels (max = 1)
;; (change-motor-inputs Δleft% Δright%) -> changes wheel torque by the delta
;; (get-left%), (get-right%), (get-robot-angle), (get-vl) or (get-vr)
;; (get-lookahead-dist) or (get-lookbehind-dist) -> to see how far away you are from a wall
;; (random) -> get's a random number between 0 and 1

;; MAKE ROBOT OPTIONS
;; #:image-url, #:name-color, #:name-font, #:body-color, #:wheel-color

(define my-bot
  (make-robot
   "simplo"
   #:image-url "https://loveonetoday.com/wp-content/uploads/2017/07/Love-One-Today-how-to-store-avocados-3a.jpg"
   ))

(define (on-tick tick#)
  (set-motors! 1 1)
  ;; write stuff here!
  )


(set-world! my-bot) ;; Leave this line how it is
(run on-tick) ;; Leave this line how it is