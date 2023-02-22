#lang racket/base

;; Once a minute, fetches the latest status from a given Mastodon instance+account that includes
;; a given hashtag AND has attached media. When a new status is detected, it retrieves the status’s
;; first media attachment and saves it to an options-specified folder, then saves the caption and
;; alt text to an options-specified JSON file.

;; The idea is that a static web page elsewhere can load the image, and use Javascript to
;; retrieve/insert the caption and alt text.
;;
;; The program’s main thread will run on a loop until halted.

(require "log.rkt"
         [prefix-in opt: "options.rkt"]
         json
         net/http-easy
         racket/file
         racket/path
         threading)

;; The status struct holds a status or post retrieved from a Mastodon server
(struct status (id timestamp url img alt-text content))

(define (handle-timeout url [ret-val (void)])
  (lambda (_exn)
    (log! 'error (format "request timed out: ~a" url))
    ret-val))

;; Fetch the latest status JSON and put the good bits into a status struct
(define (get-tagged-status)
  (define st
    (with-handlers ([exn:fail:http-easy:timeout? (handle-timeout opt:status-method '())])
      (~> (get opt:status-method
               #:auth (bearer-auth opt:token)
               #:params `((tagged . ,opt:tag) (only_media . "true") (limit . "1")))
          response-json
          car)))
  (if (null? st)
      #f
      (status (hash-ref st 'id)
              (hash-ref st 'created_at)
              (hash-ref st 'url)
              (hash-ref (car (hash-ref st 'media_attachments)) 'url)
              (hash-ref (car (hash-ref st 'media_attachments)) 'description)
              (hash-ref st 'content))))

;; Attempt to read the most recently retrieved image URL from the metadata JSON
;; file, if it exists. Used when restarting the program.
(define (read-last-image-url)
  (with-handlers ([exn:fail? (λ (_exn) "")])
    (~> (with-input-from-file opt:json-file (λ () (read-json)))
        (hash-ref 'image_url))))

(define (fetch-and-save-image! img-url)
  (define output-file (build-path opt:output-folder (format "~a.jpeg" opt:tag)))
  (with-handlers ([exn:fail:http-easy:timeout? (handle-timeout img-url)])
    (~> (get img-url)
        response-body
        (display-to-file output-file #:exists 'truncate))))

;; Write the status’s image alt text, image URL, and a caption to a JSON file
(define (write-metadata-json! stat)
  (define cap
    (string-append
     (status-content stat)
     (format "<p>Posted on <a href=\"~a\">~a</a>.</p>"
             (status-url stat)
             (ts->nice (status-timestamp stat)))))
  (define meta-json
    (hasheq 'caption cap
            'alt (status-alt-text stat)
            'image_url (status-img stat)))
  (with-output-to-file opt:json-file (λ () (write-json meta-json)) #:exists 'truncate))

(define check
  (let ([last-image (read-last-image-url)])
    (lambda ()
      (define latest (get-tagged-status))
      (define newest-image (status-img latest))
      (cond
        [(equal? last-image newest-image)
         (log! 'info "Fetched image URL, no change")]
        [else
         (log! 'info (format "New image ~a" (file-name-from-path newest-image)))
         (fetch-and-save-image! newest-image)
         (write-metadata-json! latest)
         (set! last-image newest-image)]))))

(module+ main
  (log! 'info "starting…")
  (check)
  (with-handlers ([exn:break? (λ (_exn) (log! 'info "break") (exit 0))])
    (let loop ()
      (define next-evt (alarm-evt (+ (current-inexact-milliseconds) 60000)))
      (sync/enable-break
       (handle-evt next-evt (λ (_evt) (check) (loop)))))))