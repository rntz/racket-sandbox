#lang racket

;; uses package: parser-tools-lib
(require racket/stream)
(require parser-tools/lex)
(require (prefix-in : parser-tools/lex-sre))

(require "tags.rkt")

;; Representing tokens
(provide
  (tag-out TLPAREN TRPAREN TLBRACK TRBRACK TLBRACE TRBRACE TID TSYM TNUM TSTR))

(define-tags
  TLPAREN TRPAREN TLBRACK TRBRACK TLBRACE TRBRACE
  (TID value) (TSYM value) (TNUM value) (TSTR value))


;; The actual lexing
(provide tokenize tokenize-with-position dump)

(define (tokenize input)
  (stream-map position-token-token
    (tokenize-with-position
      (if (string? input)
        (open-input-string input)
        input))))

(define (tokenize-with-position port)
  (let ([next (yak-lex port)])
    (if (eof-object? next) empty-stream
      (stream-cons next (tokenize-with-position port)))))

(define (dump port)
  (stream->list (tokenize port)))

(define yak-lex
  (lexer-src-pos
    ;; Whitespace & comments are ignored, except newlines
    [(:+ whitespace) (return-without-pos (yak-lex input-port))]
    [comment (return-without-pos (yak-lex input-port))]
    ;; Simple cases
    [(eof) (return-without-pos eof)]
    ["(" TLPAREN]   [")" TRPAREN]
    ["[" TLBRACK]   ["]" TRBRACK]
    ["{" TLBRACE]   ["}" TRBRACE]
    ;; Complex cases
    [ident (TID lexeme)]
    [symbol (TSYM lexeme)]
    [number (TNUM (string->number lexeme))]
    ["\"" (TSTR (str-lex input-port))]))

(define-lex-abbrevs
  [eol "\n"]
  [comment (:seq "#" (:* (:~ eol)))]
  ;; [inline-space (:& whitespace (:~ eol))]
  [nat (:+ numeric)]
  [ident-init (:or alphabetic (char-set "_"))]
  [ident-mid  (:or ident-init numeric)]
  [ident (:seq ident-init (:* ident-mid))]
  [symbol (:+ (char-set "`'~!@$%^&*-=+\\:<>/?|,.;"))]
  ;; Might want to loosen number definition.
  ;; Currently rejects: ".0" "1." "-.0" etc.
  ;; Note that "-12.-3" lexes as: (-12 .- 3)
  ;; TODO: maybe use "~" for negation?
  ;; maybe leave negation up to language as a prefix operator?
  [number (:seq ;(:or "" (char-set "+-"))
                nat
                (:or "" (:seq "." nat)))])

(define (str-lex port)
  (let loop ([strs '()])
    (let ([next (str-char-lex port)])
      (if next (loop (cons next strs))
        (apply string-append (reverse strs))))))

(define str-char-lex
  (lexer
    [(:* (:~ (char-set "\\\""))) lexeme]
    ;; TODO: escape sequences
    [(:seq "\\" any-char) (string (string-ref lexeme 1))]
    ["\"" #f]                           ;end of string
    ;; TODO: better errors
    [(eof) (raise 'exn:read)]
    [any-char (raise 'exn:read)]))
