#lang racket
(provide (struct-out point) (struct-out line)
         point-slope-form point-angle-form
         intersection add-points sub-points scale-point
         dist distSq)

(struct point (x y) #:transparent)
(struct line (p1 p2) #:transparent)
(define DELTA 1)
(define (point-slope-form p slope)
  (line p (point (+ (point-x p) DELTA) (+ (point-y p) (* DELTA slope)))))
(define (point-angle-form p angle)
  (if (= angle (/ pi 2))
      (line p (point (point-x p) (+ (point-y p) DELTA)))
      (point-slope-form p (tan angle))))

(define (add-points p1 p2)
  (point (+ (point-x p1) (point-x p2))
         (+ (point-y p1) (point-y p2))))
(define (sub-points p1 p2)
  (add-points p1 (scale-point -1 p2)))
(define (scale-point c p)
  (point (* c (point-x p))
         (* c (point-y p))))

(define (intersection l1 l2)
  ;; can't currently handle parallell lines
  ;; Algorithim: http://geomalgorithms.com/a05-_intersect-1.html
  (define u (sub-points (line-p2 l1) (line-p1 l1)))
  (define v (sub-points (line-p2 l2) (line-p1 l2)))
  (define w (sub-points (line-p1 l1) (line-p1 l2)))
  ; (v.y * w.x - v.x * w.y) / (v.x * u.y - v.y * u.x);
  (define s (/
             (- (* (point-y v) (point-x w)) (* (point-x v) (point-y w)))
             (- (* (point-x v) (point-y u)) (* (point-y v) (point-x u)))))
  (add-points (line-p1 l1) (scale-point s u)))

(define (distSq p1 p2)
  (+ (expt (- (point-x p1) (point-x p2)) 2)
     (expt (- (point-y p1) (point-y p2)) 2)))
(define (dist p1 p2) (sqrt (distSq p1 p2)))