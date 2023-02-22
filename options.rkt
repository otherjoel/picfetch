#lang racket/base

(require racket/file
         racket/match
         racket/runtime-path)

;;
;; Provides bindings to config options loaded from options.ini
;;

(provide token status-method tag output-folder json-file)

;; Lightweight options INI file reader.

;; Line is a “comment” (ignored) if first non-whitespace character is #
(define (comment-or-whitespace? line)
  (regexp-match? #px"^\\s*(?:#.*|)$" line))

;; "key: value" → '(key "value")
(define (line->keyval line)
  (match (regexp-match #px"^\\s*([^ :]+)\\s*:\\s*(.+)$" line)
    [(list _ keystr val) (list (string->symbol keystr) val)]
    [_ #f]))

(define (load-options filename #:defaults [opts-hash (hasheq)])
  (define lines (file->lines filename))
  (let loop ([remaining lines]
             [opts opts-hash])
    (match remaining
      [(list) opts]
      [(list* (? comment-or-whitespace?) rem) (loop rem opts)]
      [(list* line rem)
       (define new-opt (apply hash-set opts (line->keyval line)))
       (loop rem new-opt)])))

;; Using a runtime path not be the best way to do this, since this file gets
;; moved to a weird path in the distribution folder after `raco distribute`,
;; but this at least ensures it gets shipped to the web server.
(define-runtime-path options.ini "options.ini")
(define options (load-options options.ini))

(define token         (hash-ref options 'token))
(define status-method (format "https://~a/api/v1/accounts/~a/statuses"
                              (hash-ref options 'instance)
                              (hash-ref options 'account-id)))
(define tag           (hash-ref options 'tag))
(define output-folder (hash-ref options 'output-folder))
(define json-file     (hash-ref options 'json-file))