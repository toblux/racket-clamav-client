# Racket ClamAV Client

A simple ClamAV client to stream files to [clamd](https://linux.die.net/man/8/clamd) for antivirus scanning.

Please note: The functions `ping-socket` and `scan-file-socket` are only available on Unix platforms.

## Installation

Clone or download the repository and install the library with:

```shell
make install
```

## Usage

```racket
#lang racket/base

(require clamav-client
         racket/unix-socket)

;; Ping the server using a TCP connection
(ping-tcp "localhost" 3310) ; => #"PONG\0"

;; Scan a file using a TCP connection
(clean? (scan-file-tcp "/path/to/file" "localhost" 3310))

;; Scan a file using a Unix socket connection
(when unix-socket-available?
  (clean? (scan-file-socket "/path/to/file" "/tmp/clamd.socket")))

;; `hostname`, `port`, and `socket-path` are parameters and allow dynamic binding
(parameterize ([hostname "localhost"]
               [port 3310])
  (when (eq? (ping-tcp) #"PONG\0")
    (clean? (scan-file-tcp "/path/to/file"))))

(when unix-socket-available?
  (parameterize ([socket-path "/tmp/clamd.socket"])
    (when (eq? (ping-socket) #"PONG\0")
      (clean? (scan-file-socket "/path/to/file")))))
```

Take a look at the [tests](clamav-client-test/clamav-client.rkt) for further examples.
