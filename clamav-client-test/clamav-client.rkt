#lang racket/base

;; Clamd must be running for the tests to pass
(define test-hostname "localhost")
(define test-port 3310)
(define test-socket-path "/tmp/clamd.socket")

(require rackunit
         racket/unix-socket
         clamav-client)

(test-case
  "Responds to ping with pong"
  (let ([pong-response #"PONG\0"])
    (check-equal? (ping-tcp test-hostname test-port) pong-response)
    (when unix-socket-available?
      (check-equal? (ping-socket test-socket-path) pong-response))))

(define eicar-test-filename "eicar.txt")

(test-case
  "Eicar signature is found"
  (let ([scan-result #"stream: Eicar-Signature FOUND\0"])
    (check-equal? (scan-file-tcp eicar-test-filename test-hostname test-port) scan-result)
    (when unix-socket-available?
      (check-equal? (scan-file-socket eicar-test-filename test-socket-path) scan-result))))

(test-case
  "clean? works"
  (let ([src-filename "clamav-client.rkt"])
    (check-false (clean? (scan-file-tcp eicar-test-filename test-hostname test-port)))
    (check-true (clean? (scan-file-tcp src-filename test-hostname test-port)))
    (when unix-socket-available?
      (check-false (clean? (scan-file-socket eicar-test-filename test-socket-path)))
      (check-true (clean? (scan-file-socket src-filename test-socket-path))))))