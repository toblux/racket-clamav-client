# Racket ClamAV Client

A simple ClamAV client to stream files to [clamd](https://linux.die.net/man/8/clamd) for antivirus scanning.

Please note: The functions `ping-socket` and `scan-file-socket` are only available on Unix platforms.

## Installation

Clone or download the repository and install the library with:

```shell
raco pkg install --copy ./clamav-client-lib
```

## Usage

```racket
(require clamav-client)

;; Scan a file using a TCP connection
(clean? (scan-file-tcp "/path/to/file" "localhost" 3310))

;; Scan a file using a Unix socket connection
(clean? (scan-file-socket "/path/to/file" "/tmp/clamd.socket"))
```

Take a look at the [tests](clamav-client-test/clamav-client.rkt) for further examples.
