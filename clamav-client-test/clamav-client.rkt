#lang racket/base

;;; clamd must be running and accepting TCP connections at "localhost:3310" for the tests to pass

(require rackunit
         racket/unix-socket
         clamav-client)

(define eicar-test-filename "eicar.txt")
(define clean-test-filename "clamav-client.rkt")

;; StreamMaxLength in clamd.conf is limited to 1 MB.
;; The test file is exactly 1 byte larger than allowed
(define stream-max-test-filename "stream-max-length+1byte-test-file.bin")

(define pong-response #"PONG\0")
(define stream-ok-response #"stream: OK\0")
(define eicar-found-response #"stream: Eicar-Signature FOUND\0")
(define size-limit-response #"INSTREAM size limit exceeded. ERROR\0")

;;; Unit tests

(test-case
  "error? works"
  (check-false (error? pong-response))
  (check-false (error? eicar-found-response))
  (check-false (error? stream-ok-response))
  (check-true (error? size-limit-response)))

(test-case
  "clean? works"
  (check-false (clean? eicar-found-response))
  (check-true (clean? stream-ok-response)))

;;; Integration tests

(test-case
  "Responds to ping with pong"
  (check-equal? (ping-tcp) pong-response)
  (check-equal? (ping-tcp "localhost" 3310) pong-response)

  (when unix-socket-available?
    (check-equal? (ping-socket) pong-response)
    (check-equal? (ping-socket "/tmp/clamd.socket") pong-response)))

(test-case
  "Eicar signature is found"
  (check-equal? (scan-file-tcp eicar-test-filename) eicar-found-response)
  (check-equal? (scan-file-tcp eicar-test-filename "localhost" 3310) eicar-found-response)

  (when unix-socket-available?
    (check-equal? (scan-file-socket eicar-test-filename) eicar-found-response)
    (check-equal? (scan-file-socket eicar-test-filename "/tmp/clamd.socket") eicar-found-response)))

(test-case
  "File size limit exceeded works"
  (check-equal? (scan-file-tcp stream-max-test-filename) size-limit-response)

  (when unix-socket-available?
    (check-equal? (scan-file-socket stream-max-test-filename) size-limit-response)))

(test-case
  "Parameterization works"
  (parameterize ([hostname "localhost"]
                 [port 3310])
    (check-equal? (scan-file-tcp eicar-test-filename) eicar-found-response)
    (check-equal? (scan-file-tcp clean-test-filename) stream-ok-response))

  (when unix-socket-available?
    (parameterize ([socket-path "/tmp/clamd.socket"]
                   [chunk-size 128])
      (check-equal? (scan-file-socket eicar-test-filename) eicar-found-response)
      (check-equal? (scan-file-socket clean-test-filename) stream-ok-response))))
