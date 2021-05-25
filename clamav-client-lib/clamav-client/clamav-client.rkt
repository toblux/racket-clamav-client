#lang typed/racket/base

(provide ping-tcp
         ping-socket
         scan-file-tcp
         scan-file-socket
         clean?)

(require racket/string)

(require/typed racket/unix-socket
               [unix-socket-available? Boolean]
               [unix-socket-connect (-> String (Values Input-Port Output-Port))])

(require/typed racket/tcp
               [tcp-connect (-> String Positive-Index (Values Input-Port Output-Port))])

;;; Clamd commands are documented at https://linux.die.net/man/8/clamd
;;; or simply run `man clamd`

(define default-socket-path "/tmp/clamd.socket")
(define default-hostname "localhost")
(define default-port 3310)

;; Chunk size must not exceed StreamMaxLength as defined in clamd.conf
(define default-chunk-size 2048)

;;; Helper functions

;; Read all bytes from input-port into memory
(: read-all-bytes (-> Integer Input-Port Bytes))
(define (read-all-bytes chunk-size input-port)
  (let ([bytes (read-bytes chunk-size input-port)])
    (if (eof-object? bytes)
        #""
        (bytes-append bytes (read-all-bytes chunk-size input-port)))))

;;; Ping clamd server

(: ping (-> Input-Port Output-Port Bytes))
(define (ping in out)
  ;; Send PING command
  (write-bytes #"zPING\0" out)
  (flush-output out)

  ;; Close out
  (close-output-port out)
  (unless (port-closed? out)
    (error 'out "output port not closed"))

  ;; Read from in, close port, and return response
  (let* ([pong-response #"PONG\0"]
         [chunk-size (bytes-length pong-response)]
         [response (read-all-bytes chunk-size in)])
    (close-input-port in)
    (unless (port-closed? in)
      (error 'in "input port not closed"))
    response))

(: ping-tcp (->* () (String Positive-Index) Bytes))
(define (ping-tcp [hostname default-hostname]
                  [port default-port])
  (call-with-values (lambda () (tcp-connect hostname port)) ping))

(: ping-socket (->* () (String) Bytes))
(define (ping-socket [socket-path default-socket-path])
  (unless unix-socket-available?
    (error "Unix sockets are not available on this platform"))
  (call-with-values (lambda () (unix-socket-connect socket-path)) ping))

;;; Scan input-port

(: scan-input-port (-> Input-Port Integer (-> Input-Port Output-Port Bytes)))
(define ((scan-input-port input-port chunk-size) in out)
  ;; Send INSTREAM command
  (write-bytes #"zINSTREAM\0" out)

  ;; Stream chunk-sized bytes from input-port to out
  (for ([bs (in-port (lambda ([in : Input-Port]) (read-bytes chunk-size in)) input-port)])
    (write-bytes (integer->integer-bytes (bytes-length bs) 4 #f #t) out)
    (write-bytes bs out))

  ;; Terminate by sending a zero-length chunk
  (write-bytes (bytes 0 0 0 0) out)
  (flush-output out)

  (let ([bytes (read-all-bytes chunk-size in)])
    (close-input-port in)
    (unless (port-closed? in)
      (error 'in "input port not closed"))
    bytes))

;;; Scan file at path

(: scan-file-tcp (->* (String) (String Positive-Index Integer) Bytes))
(define (scan-file-tcp path
                       [hostname default-hostname]
                       [port default-port]
                       [chunk-size default-chunk-size])
  (call-with-values (lambda () (tcp-connect hostname port))
                    (scan-input-port (open-input-file path) chunk-size)))

(: scan-file-socket (->* (String) (String Integer) Bytes))
(define (scan-file-socket path
                          [socket-path default-socket-path]
                          [chunk-size default-chunk-size])
  (unless unix-socket-available?
    (error "Unix sockets are not available on this platform"))
  (call-with-values (lambda () (unix-socket-connect socket-path))
                    (scan-input-port (open-input-file path) chunk-size)))

(: clean? (-> Bytes Boolean))
(define (clean? scan-result)
  (let ([result (bytes->string/utf-8 scan-result)])
    (and (string-contains? result "OK")
         (not (string-contains? result "FOUND")))))
