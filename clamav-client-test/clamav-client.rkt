#lang racket/base

;;; clamd must be running and accepting
;;; TCP connections at "localhost:3310" and
;;; Unix socket connections at "/tmp/clamd.socket"
;;; for the tests to pass.

(require rackunit
         racket/unix-socket
         clamav-client)

(define eicar-test-filename "eicar.txt")
(define clean-test-filename "clamav-client.rkt")

(define stream-ok-response #"stream: OK\0")
(define eicar-found-response #"stream: Eicar-Signature FOUND\0")

(check-false (clean? eicar-found-response))
(check-true (clean? stream-ok-response))

(test-case
  "Responds to ping with pong"
  (let ([pong-response #"PONG\0"])
    (check-equal? (ping-tcp) pong-response)
    (when unix-socket-available?
      (check-equal? (ping-socket) pong-response))))

(test-case
  "Eicar signature is found"
  (check-equal? (scan-file-tcp eicar-test-filename) eicar-found-response)
  (when unix-socket-available?
    (check-equal? (scan-file-socket eicar-test-filename) eicar-found-response)))

(test-case
  "clean? works"
  (check-false (clean? (scan-file-tcp eicar-test-filename)))
  (check-true (clean? (scan-file-tcp clean-test-filename)))
  (when unix-socket-available?
    (check-false (clean? (scan-file-socket eicar-test-filename)))
    (check-true (clean? (scan-file-socket clean-test-filename)))))
