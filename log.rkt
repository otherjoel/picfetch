#lang racket/base

(require racket/date
         racket/match
         threading)

;; Lightweight logging to stderr

(provide ts->nice
         log!
         panic)

;; leading zero
(define (lz num)
  (define nstr (number->string num))
  (if (< num 10) (string-append "0" nstr) nstr))

;; convert yyy-mm-dd strings to nice time strings
(define (ts->nice str)
  (match (regexp-match #px"^(\\d{4})-(\\d{2})-(\\d{2})" str)
    [(list _ yr month day)
     (~> (find-seconds 0 0 0
               (string->number day)
               (string->number month)
               (string->number yr))
         seconds->date
         date->string)]
    [_ #f]))

(define (ts)
  (match (current-date)
    [(date sec min hr day month yr _ _ _ _)
     (format "~a-~a-~a ~a:~a:~a" yr (lz month) (lz day) (lz hr) (lz min) (lz sec))]))

(define (log! type msg)
  (displayln (format "[~a] ~a: ~a" (ts) type msg) (current-error-port)))

(define (panic msg code)
  (log 'fatal msg)
  (exit code))