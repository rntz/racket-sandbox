#lang racket

(require "util.rkt")
(require "values.rkt")
(require "env.rkt")
(require "parse.rkt")
(require "builtin-parse.rkt")

(define parse-env builtin-parse-env)
(define resolve-env env-empty)

(define (show x) (call-with-output-string
                   (lambda (p) (print x p 1))))

(define (printfln fmt . args)
  (apply printf fmt args)
  (display "\n"))

(define (doparse p what)
  (if what (parse-all p parse-env what)
    (parse p parse-env
      ;; this is an utter hack to work inside the repl
      (begin (read-line) (read-line)))))

(define (test-expr [what #f])
  (define ast (doparse p-expr what))
  (printfln "parsed: ~a" (show (expr-sexp ast)))
  (define code (expr-compile ast resolve-env))
  (printfln "compiled: ~a" (show code))
  (printfln "evaled: ~a" (show (eval code))))

(define (test-decl [what #f])
  (define ast (doparse p-decl what))
  (printfln "parsed: ~a" (show (decl-sexp ast)))
  (printfln "resolveExt: ~a" (show (decl-resolveExt ast)))
  (define id-codes (decl-compile ast resolve-env))
  (printfln "compiled: ~a" (show id-codes))
  (printfln "evaled: ~a"
    (show
      (eval `(begin
               ,@(for/list ([x id-codes]) `(define ,@x))
               (list ,@(map (compose (lambda (x) `(list ',x ,x)) car)
                         id-codes)))))))

(define (test-top-one [what #f])
  (define result (doparse (parse-eval-one resolve-env) what))
  result)

(define (test-top [what #f])
  (define result (doparse (parse-eval resolve-env) what))
  result)