#lang typed/racket/base

(provide ping-tcp
         scan-file-tcp
         clean?

         ;; Only available on Unix platforms
         ping-socket
         scan-file-socket

         ;; Parameters
         socket-path
         hostname
         port
         chunk-size)

(require racket/function
         racket/path
         racket/port
         racket/string)

(require/typed racket/unix-socket
               [unix-socket-available? Boolean]
               [unix-socket-connect (-> String (Values Input-Port Output-Port))])

(require/typed racket/tcp
               [tcp-connect (-> String Positive-Index (Values Input-Port Output-Port))])

;;; Clamd commands are documented at https://linux.die.net/man/8/clamd
;;; or simply run `man clamd`

(define socket-path (make-parameter "/tmp/clamd.socket"))

(define hostname (make-parameter "localhost"))

(: port (Parameterof Positive-Index))
(define port (make-parameter 3310))

;; Chunk size must not exceed StreamMaxLength as defined in clamd.conf
(: chunk-size (Parameterof Positive-Index))
(define chunk-size (make-parameter 2048))

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

  ;; Read from in, close port, and return response bytes
  (port->bytes in #:close? #t))

(: ping-tcp (->* () (String Positive-Index) Bytes))
(define (ping-tcp [hostname (hostname)]
                  [port (port)])
  (call-with-values (thunk (tcp-connect hostname port)) ping))

(: ping-socket (->* () (String) Bytes))
(define (ping-socket [socket-path (socket-path)])
  (unless unix-socket-available?
    (error "Unix sockets are not available on this platform"))
  (call-with-values (thunk (unix-socket-connect socket-path)) ping))

;;; Scan input-port

(: scan-input-port (-> Input-Port Integer (-> Input-Port Output-Port Bytes)))
(define ((scan-input-port input-port chunk-size) in out)
  ;; Send INSTREAM command
  (write-bytes #"zINSTREAM\0" out)

  ;; Stream chunk-sized bytes from input-port to out
  (for ([bs (in-port (λ ([in : Input-Port]) (read-bytes chunk-size in)) input-port)])
    (write-bytes (integer->integer-bytes (bytes-length bs) 4 #f #t) out)
    (write-bytes bs out))

  ;; Terminate by sending a zero-length chunk
  (write-bytes (bytes 0 0 0 0) out)
  (flush-output out)
  
  ;; Read from in, close port, and return response bytes
  (port->bytes in #:close? #t))

;;; Scan file at path

(: scan-file-tcp (->* (Path-String) (String Positive-Index Integer) Bytes))
(define (scan-file-tcp path
                       [hostname (hostname)]
                       [port (port)]
                       [chunk-size (chunk-size)])
  (let ([normalized-path (simple-form-path path)])
    (call-with-values (thunk (tcp-connect hostname port))
                      (scan-input-port (open-input-file normalized-path) chunk-size))))

(: scan-file-socket (->* (Path-String) (String Integer) Bytes))
(define (scan-file-socket path
                          [socket-path (socket-path)]
                          [chunk-size (chunk-size)])
  (unless unix-socket-available?
    (error "Unix sockets are not available on this platform"))
  (let ([normalized-path (simple-form-path path)])
    (call-with-values (thunk (unix-socket-connect socket-path))
                      (scan-input-port (open-input-file normalized-path) chunk-size))))

(: clean? (-> Bytes Boolean))
(define (clean? scan-result)
  (let ([result (bytes->string/utf-8 scan-result)])
    (and (string-contains? result "OK")
         (not (string-contains? result "FOUND")))))
