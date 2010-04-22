#lang scribble/doc
@(require "mz.ss")
@(require (for-label syntax/modcollapse))

@(define contract-eval
   (lambda ()
     (let ([the-eval (make-base-eval)])
       (the-eval '(require racket/contract))
       the-eval)))

@title[#:tag "contracts" #:style 'toc]{Contracts}

@guideintro["contracts"]{contracts}

The contract system guards one part of a program from
another. Programmers specify the behavior of a module exports via
@scheme[provide/contract] and the contract system enforces those
constraints.

@note-lib[racket/contract #:use-sources (racket/contract/private/ds
                                         racket/contract/private/base
                                         racket/contract/private/guts
                                         racket/contract/private/misc
                                         racket/contract/private/provide)]

@deftech{Contracts} come in two forms: those constructed by the
various operations listed in this section of the manual, and various
ordinary Scheme values that double as contracts, including 
@itemize[
@item{@tech{symbols}, @tech{booleans}, @tech{characters}, and
@scheme[null], which are treated as contracts that recognize
themselves, using @scheme[eq?], }

@item{@tech{strings} and @tech{byte strings}, which are treated as contracts
that recognize themselves using @scheme[equal?], }

@item{@tech{numbers}, which are treated as contracts
that recognize themselves using @scheme[=],}

@item{@tech{regular expressions}, which are treated as contracts that recognize @tech{byte strings} and @tech{strings} that match the regular expression, and }

@item{predicates: any procedure of arity 1 is treated as a
predicate. During contract checking, it is applied to the values that
appear and should return @scheme[#f] to indicate that the contract
failed, and anything else to indicate it passed.}

]

@local-table-of-contents[]

@; ----------------------------------------

@section{Data-structure Contracts}

A @deftech{flat contract} can be fully checked immediately for
a given value.

@defproc[(flat-contract [predicate (any/c . -> . any/c)]) flat-contract?]{

Constructs a @tech{flat contract} from @scheme[predicate]. A value
satisfies the contract if the predicate returns a true value.}


@defproc[(flat-named-contract [type-name any/c] [predicate (or/c flat-contract? (any/c . -> . any))])
         flat-contract?]{

On predicates like @scheme[flat-contract], but the first argument must be the
(quoted) name of a contract used for error reporting. 
For example, 
@schemeblock[(flat-named-contract
              'odd-integer 
              (lambda (x) (and (integer? x) (odd? x))))]
turns the predicate into a contract with the name @tt{odd-integer}.

On flat contracts, the new flat contract is the same as the old except for
the name.
}

@defthing[any/c flat-contract?]{

A flat contract that accepts any value.

When using this contract as the result portion of a function contract,
consider using @scheme[any] instead; using @scheme[any] leads to
better memory performance, but it also allows multiple results.}


@defthing[none/c flat-contract?]{

A @tech{flat contract} that accepts no values.}


@defproc[(or/c [contract contract?] ...)
         contract?]{

Takes any number of contracts and returns
a contract that accepts any value that any one of the contracts
accepts, individually.

The @scheme[or/c] result tests any value by applying the contracts in
order, from left to right, with the exception that it always moves the
non-@tech{flat contracts} (if any) to the end, checking them
last. Thus, a contract such as @scheme[(or/c (not/c real?) 
positive?)] is guaranteed to only invoke the @scheme[positive?] 
predicate on real numbers.

If all of the arguments are procedures or @tech{flat contracts}, the
result is a @tech{flat contract}. If only one of the arguments is a
higher-order contract, the result is a contract that just checks the
flat contracts and, if they don't pass, applies the higher-order
contract.

If there are multiple higher-order contracts, @scheme[or/c] uses
@scheme[contract-first-order-passes?] to distinguish between
them. More precisely, when an @scheme[or/c] is checked, it first
checks all of the @tech{flat contracts}. If none of them pass, it
calls @scheme[contract-first-order-passes?] with each of the
higher-order contracts. If only one returns true, @scheme[or/c] uses
that contract. If none of them return true, it signals a contract
violation. If more than one returns true, it also signals a contract
violation.
For example, this contract
@schemeblock[
(or/c (-> number? number?)
      (-> string? string? string?))
]
does not accept a function like this one: @scheme[(lambda args ...)] 
since it cannot tell which of the two arrow contracts should be used
with the function.
}
 
@defproc[(and/c [contract (or/c contract? (any/c . -> . any/c))] ...)
         contract?]{

Takes any number of contracts and returns a contract that checks that
accepts any value that satisfies all of the contracts, simultaneously.

If all of the arguments are procedures or @tech{flat contracts},
the result is a @tech{flat contract}.

The contract produced by @scheme[and/c] tests any value by applying
the contracts in order, from left to right.}


@defproc[(not/c [flat-contract (or/c flat-contract? (any/c . -> . any/c))]) 
         flat-contract?]{

Accepts a flat contracts or a predicate and returns a flat contract
that checks the inverse of the argument.}


@defproc[(=/c [z real?]) flat-contract?]{

Returns a flat contract that requires the input to be a number and
@scheme[=] to @scheme[z].}


@defproc[(</c [n real?]) flat-contract?]{

Returns a flat contract that requires the input to be a number and
@scheme[<] to @scheme[n].}


@defproc[(>/c [n real?]) flat-contract?]{
Like @scheme[</c], but for @scheme[>].}


@defproc[(<=/c [n real?]) flat-contract?]{
Like @scheme[</c], but for @scheme[<=].}


@defproc[(>=/c [n real?]) flat-contract?]{
Like @scheme[</c], but for @scheme[>=].}

@defproc[(between/c [n real?] [m real?])
flat-contract?]{ Returns a flat contract that requires the
input to be a between @scheme[n] and @scheme[m] or equal to
one of them.}

@defproc[(real-in [n real?][m real?]) flat-contract?]{

Returns a flat contract that requires the input to be a real number
between @scheme[n] and @scheme[m], inclusive.}


@defproc[(integer-in [j exact-integer?][k exact-integer?]) flat-contract?]{

Returns a flat contract that requires the input to be an exact integer
between @scheme[j] and @scheme[k], inclusive.}


@defthing[natural-number/c flat-contract?]{

A flat contract that requires the input to be an exact non-negative integer.}


@defproc[(string-len/c [len exact-nonnegative-integer?]) flat-contract?]{

Returns a flat contract that recognizes strings that have fewer than
@scheme[len] characters.}


@defthing[false/c flat-contract?]{

This is just @scheme[#f]. It is here for backwards compatibility.}


@defthing[printable/c flat-contract?]{

A flat contract that recognizes values that can be written out and
read back in with @scheme[write] and @scheme[read].}


@defproc[(one-of/c [v any/c] ...+) flat-contract?]{

Accepts any number of atomic values and returns a flat contract that
recognizes those values, using @scheme[eqv?]  as the comparison
predicate.  For the purposes of @scheme[one-of/c], atomic values are
defined to be: characters, symbols, booleans, null keywords, numbers,
void, and undefined.}


@defproc[(symbols [sym symbol?] ...+) flat-contract?]{

Accepts any number of symbols and returns a flat contract that
recognizes those symbols.}


@defproc[(vectorof [c (or/c flat-contract? (any/c . -> . any/c))]) flat-contract?]{

Accepts a @tech{flat contract} (or a predicate that is converted to a
flat contract via @scheme[flat-contract]) and returns a flat contract
that checks for vectors whose elements match the original contract.}


@defproc[(vector-immutableof [c (or/c contract? (any/c . -> . any/c))]) contract?]{

Like @scheme[vectorof], but the contract needs not be a @tech{flat
contract}. Beware that when this contract is applied to a
value, the result is not @scheme[eq?] to the input.}


@defproc[(vector/c [c (or/c flat-contract? (any/c . -> . any/c))] ...) flat-contract?]{

Accepts any number of flat contracts (or predicates that are converted
to flat contracts via @scheme[flat-contract]) and returns a
flat-contract that recognizes vectors. The number of elements in the
vector must match the number of arguments supplied to
@scheme[vector/c], and each element of the vector must match the
corresponding flat contract.}


@defproc[(vector-immutable/c [c (or/c contract? (any/c . -> . any/c))] ...) contract?]{

Like @scheme[vector/c], but the individual contracts need not be
@tech{flat contracts}. Beware that when this contract is applied to a
value, the result is not @scheme[eq?] to the input.}


@defproc[(box/c [c (or/c flat-contract? (any/c . -> . any/c))]) flat-contract?]{

Returns a flat-contract that recognizes boxes. The content of the box
must match @scheme[c].}


@defproc[(box-immutable/c [c (or/c contract? (any/c . -> . any/c))]) contract?]{

Like @scheme[box/c], but @scheme[c] need not be @tech{flat
contract}. Beware that when this contract is applied to a value, the
result is not @scheme[eq?] to the input.}


@defproc[(listof [c (or/c contract? (any/c . -> . any/c))]) contract?]{

Returns a contract that recognizes a list whose every element matches
the contract @scheme[c]. Beware that when this contract is applied to
a value, the result is not necessarily @scheme[eq?] to the input.}


@defproc[(non-empty-listof [c (or/c contract? (any/c . -> . any/c))]) contract?]{

Returns a contract that recognizes non-empty lists whose elements match
the contract @scheme[c]. Beware that when this contract is applied to
a value, the result is not necessarily @scheme[eq?] to the input.}

@defproc[(cons/c [car-c contract?][cdr-c contract?]) contract?]{

Produces a contract the recognizes pairs first and second elements
match @scheme[car-c] and @scheme[cdr-c], respectively. Beware that
when this contract is applied to a value, the result is not
necessarily @scheme[eq?] to the input.}


@defproc[(list/c [c (or/c contract? (any/c . -> . any/c))] ...) contract?]{

Produces a contract for a list. The number of elements in the list
must match the number of arguments supplied to @scheme[list/c], and
each element of the list must match the corresponding contract. Beware
that when this contract is applied to a value, the result is not
necessarily @scheme[eq?] to the input.}


@defproc[(syntax/c [c flat-contract?]) flat-contract?]{

Produces a flat contract that recognizes syntax objects whose
@scheme[syntax-e] content matches @scheme[c].}


@defform[(struct/c struct-id flat-contract-expr ...)]{

Produces a flat contract that recognizes instances of the structure
type named by @scheme[struct-id], and whose field values match the
@tech{flat contracts} produced by the @scheme[flat-contract-expr]s.}


@defproc[(parameter/c [c contract?]) contract?]{

Produces a contract on parameters whose values must match
@scheme[contract].}

@defproc[(hash/c [key contract?]
                 [val contract?] 
                 [#:immutable immutable (or/c #t #f 'dont-care) 'dont-care])
         contract?]{
Produces a contract that recognizes @scheme[hash] tables with keys and values
as specified by the @scheme[key] and @scheme[val] arguments.

If the @scheme[immutable] argument is @scheme[#f] or
@scheme['dont-care], then the resulting contract is a flat contract,
and the @scheme[key] and @scheme[val] arguments must also be flat
contracts. 

If @scheme[immutable] is @scheme[#t], then the other arguments do not
have to be flat contracts, the result is not a flat contract, and
checking this contract involves making a copy of the hash-table.
}


@defform[(flat-rec-contract id flat-contract-expr ...)]

Constructs a recursive @tech{flat contract}. A
@scheme[flat-contract-expr] can refer to @scheme[id] to refer
recursively to the generated contract.

For example, the contract

@schemeblock[
   (flat-rec-contract sexp
     (cons/c sexp sexp)
     number?
     symbol?)
]

is a flat contract that checks for (a limited form of)
S-expressions. It says that an @scheme[sexp] is either two
@scheme[sexp] combined with @scheme[cons], or a number, or a symbol.

Note that if the contract is applied to a circular value, contract
checking will not terminate.}


@defform[(flat-murec-contract ([id flat-contract-expr ...] ...) body ...+)]{

A generalization of @scheme[flat-rec-contract] for defining several
mutually recursive flat contracts simultaneously. Each @scheme[id] is
visible in the entire @scheme[flat-murec-contract] form, and the
result of the final @scheme[body] is the result of the entire form.}


@defidform[any]{

Represents a contract that is always satisfied. In particular, it can accept
multiple values.  It can only be used in a result position of contracts like
@scheme[->]. Using @scheme[any] elsewhere is a syntax error.}

@defform[(promise/c expr)]{

Constructs a contract on a promise. The contract does not force the
promise, but when the promise is forced, the contract checks that the
result value meets the contract produced by @scheme[expr].}

@defproc[(new-∃/c [name symbol?]) contract?]{
  Constructs a new existential contract. 
  
  Existential contracts accept all values when in positive positions (e.g., function
  returns) and wraps the value in an opaque struct, hiding the precise value. 
  In negative positions (e.g. function inputs), 
  it accepts only values that were previously accepted in negative positions (by checking
  for the wrappers).
  
  For example, this contract:
  @schemeblock[(let ([a (new-∃/c 'a)])
                 (-> (-> a a)
                     any/c))]
  describes a function that accepts the identity function (or a non-terminating function)
  and returns an arbitrary value. That is, the first use of the @scheme[a] appears in a
  positive position and thus inputs to that function are wrapped with an opaque struct.
  Then, when the function returns, it is checked to see if the result is wrapped, since
  the second @scheme[a] appears in a negative position.
  
}

@; ------------------------------------------------------------------------

@section{Function Contracts}

A @deftech{function contract} wraps a procedure to delay
checks for its arguments and results. There are three
primary function contract combinators that have increasing
amounts of expressiveness and increasing additional
overheads. The first @scheme[->] is the cheapest. It
generates wrapper functions that can call the original
function directly. Contracts built with @scheme[->*] require
packaging up arguments as lists in the wrapper function and
then using either @scheme[keyword-apply] or
@scheme[apply]. Finally, @scheme[->d] is the most expensive,
because it requires delaying the evaluation of the contract
expressions for the domain and range until the function
itself is called or returns.

The @scheme[case->] contract is a specialized contract,
designed to match @scheme[case-lambda] and
@scheme[unconstrained-domain->] allows range checking
without requiring that the domain have any particular shape
(see below for an example use).

@defform*/subs[#:literals (any values)
               [(-> dom ... range)]
               ([dom dom-expr (code:line keyword dom-expr)]
                [range range-expr (values range-expr ...) any])]{

Produces a contract for a function that accepts a fixed
number of arguments and returns either a fixed number of
results or completely unspecified results (the latter when
@scheme[any] is specified).

Each @scheme[dom-expr] is a contract on an argument to a
function, and each @scheme[range-expr] is a contract on a
result of the function.

@margin-note{Using an @scheme[->] between two whitespace-delimited
@schemeparenfont{.}s is the same as putting the @scheme[->] right
after the enclosing open parenthesis. See
@guidesecref["lists-and-syntax"] or @secref["parse-pair"] for more
information.}

For example,

@schemeblock[(integer? boolean? . -> . integer?)] 

produces a contract on functions of two arguments. The first argument
must be an integer, and the second argument must be a boolean. The
function must produce an integer.

A domain specification may include a keyword. If so, the function must
accept corresponding (mandatory) keyword arguments, and the values for
the keyword arguments must match the corresponding contracts. For
example:

@schemeblock[(integer? #:x boolean? . -> . integer?)]

is a contract on a function that accepts a by-position argument that
is an integer and a @scheme[#:x] argument is that a boolean.

If @scheme[any] is used as the last sub-form for @scheme[->], no
contract checking is performed on the result of the function, and
thus any number of values is legal (even different numbers on different
invocations of the function).

If @scheme[(values range-expr ...)] is used as the last sub-form of
@scheme[->], the function must produce a result for each contract, and
each value must match its respective contract.}


@defform*/subs[#:literals (any values)
          [(->* (mandatory-dom ...) (optional-dom ...) rest range)]
          ([mandatory-dom dom-expr (code:line keyword dom-expr)]
           [optional-dom dom-expr (code:line keyword dom-expr)]
           [rest (code:line) (code:line #:rest rest-expr)]
           [range range-expr (values range-expr ...) any])]{

The @scheme[->*] contract combinator produces contracts for
functions that accept optional arguments (either keyword or
positional) and/or arbitrarily many arguments. The first
clause of a @scheme[->*] contract describes the mandatory
arguments, and is similar to the argument description of a
@scheme[->] contract. The second clause describes the
optional arguments. The last clause describes the range of
the function. It can either be @scheme[any] or a
sequence of contracts, indicating that the function must
return multiple values. If present, the @scheme[rest-expr]
contract governs the arguments in the rest parameter.

As an example, the contract 
@schemeblock[(->* () (boolean? #:x integer?) #:rest (listof symbol?) symbol?)] 
matches functions that optionally accept a boolean, an
integer keyword argument @scheme[#:x] and arbitrarily more
symbols, and that return a symbol.

}

@defform*/subs[#:literals (any values)
[(->d (mandatory-dependent-dom ...) 
      (optional-dependent-dom ...) 
      dependent-rest
      pre-cond
      dep-range)]
([mandatory-dependent-dom [id dom-expr] (code:line keyword [id dom-expr])]
 [optional-dependent-dom [id dom-expr] (code:line keyword [id dom-expr])]
 [dependent-rest (code:line) (code:line #:rest id rest-expr)]
 [pre-cond (code:line) (code:line #:pre-cond boolean-expr)]
 [dep-range any
            (code:line [_ range-expr] post-cond)
            (code:line (values [_ range-expr] ...) post-cond)
            (code:line [id range-expr] post-cond)
            (code:line (values [id range-expr] ...) post-cond)]
 [post-cond (code:line) (code:line #:post-cond boolean-expr)]
)]{

The @scheme[->d] is similar in shape to @scheme[->*], with
two extensions: names have been added to each argument and
result, which allows the contracts to depend on the values
of the arguments and results, and pre- and post-condition
expressions have been added in order to express contracts
that are not naturally tied to a particular argument or
result.

The first two subforms of a @scheme[->d] contract cover the
mandatory and optional arguments. Following that is an
optional rest-args contract, and an optional
pre-condition. The @scheme[dep-range] non-terminal covers
the possible post-condition contracts. If it is
@scheme[any], then any result (or results) are
allowed. Otherwise, the result contract can be a name and a
result contract, or a multiple values return and, in either
of the last two cases, it may be optionally followed by a
post-condition.

Each of the @scheme[id]s on an argument (including the rest
argument) is visible in all of the sub-expressions of
@scheme[->d]. Each of the @scheme[id]s on a result is
visible in the subexpressions of the @scheme[dep-range].

If the identifier position of the range contract is
@scheme[_] (an underscore), then the range contract
expressions are evaluated when the function is called (and
the underscore is not bound in the range). Otherwise the
range expressions are evaluated when the function returns.

If there are optional arguments that are not supplied, then 
the corresponding variables will be bound to a special value
called the @scheme[unsupplied-arg] value.
}

@defform*/subs[#:literals (any values ->)
[(case-> (-> dom-expr ... rest range) ...)]
([rest (code:line) (code:line #:rest rest-expr)]
 [range range-expr (values range-expr ...) any])]{
This contract form is designed to match
@scheme[case-lambda]. Each argument to @scheme[case->] is a
contract that governs a clause in the
@scheme[case-lambda]. If the @scheme[#:rest] keyword is
present, the corresponding clause must accept an arbitrary
number of arguments. The @scheme[range] specification is
just like that for @scheme[->] and @scheme[->*]. 
}


@defform[(unconstrained-domain-> range-expr ...)]{

Constructs a contract that accepts a function, but makes no constraint
on the function's domain. The @scheme[range-expr]s determine the number
of results and the contract for each result.

Generally, this contract must be combined with another contract to
ensure that the domain is actually known to be able to safely call the
function itself.

For example, the contract

@schemeblock[
(provide/contract 
 [f (->d ([size natural-number/c]
          [proc (and/c (unconstrained-domain-> number?)
                       (lambda (p) 
                         (procedure-arity-includes? p size)))])
         ()
         number?)])
]

says that the function @scheme[f] accepts a natural number
and a function. The domain of the function that @scheme[f]
accepts must include a case for @scheme[size] arguments,
meaning that @scheme[f] can safely supply @scheme[size]
arguments to its input.

For example, the following is a definition of @scheme[f] that cannot
be blamed using the above contract:

@schemeblock[
(define (f i g) 
  (apply g (build-list i add1)))
]}


@; ------------------------------------------------------------------------

@section{Lazy Data-structure Contracts}

@defform[
(define-contract-struct id (field-id ...))
]{

Like @scheme[define-struct], but with two differences: it does not
define field mutators, and it does define two contract constructors:
@scheme[id]@schemeidfont{/c} and @scheme[id]@schemeidfont{/dc}. The
first is a procedure that accepts as many arguments as there are
fields and returns a contract for struct values whose fields match the
arguments. The second is a syntactic form that also produces contracts
on the structs, but the contracts on later fields may depend on the
values of earlier fields. 

The generated contract combinators are @italic{lazy}: they only verify
the contract holds for the portion of some data structure that is
actually inspected. More precisely, a lazy data structure contract is
not checked until a selector extracts a field of a struct.

@specsubform/subs[
(#,(elem (scheme id) (schemeidfont "/dc")) field-spec ...)

([field-spec
  [field-id contract-expr]
  [field-id (field-id ...) contract-expr]])
]{

In each @scheme[field-spec] case, the first @scheme[field-id]
specifies which field the contract applies to; the fields must be
specified in the same order as the original
@scheme[define-contract-struct]. The first case is for when the
contract on the field does not depend on the value of any other
field. The second case is for when the contract on the field does
depend on some other fields, and the parenthesized @scheme[field-id]s
indicate which fields it depends on; these dependencies can only be to
earlier fields.}

As an example, consider the following module:

@(begin
#reader scribble/comment-reader
[schemeblock
(module product mzscheme
  (require mzlib/contract)

  (define-contract-struct kons (hd tl))
  
  ;; @scheme[sorted-list/gt : number -> contract]
  ;; produces a contract that accepts
  ;; sorted kons-lists whose elements
  ;; are all greater than @scheme[num].
  (define (sorted-list/gt num)
    (or/c null?
          (kons/dc [hd (>=/c num)]
                   [tl (hd) (sorted-list/gt hd)])))
  
  ;; @scheme[product : kons-list -> number]
  ;; computes the product of the values
  ;; in the list. if the list contains
  ;; zero, it avoids traversing the rest
  ;; of the list.
  (define (product l)
    (cond
      [(null? l) 1]
      [else
       (if (zero? (kons-hd l))
           0
           (* (kons-hd l) 
              (product (kons-tl l))))]))
  
  (provide kons? make-kons kons-hd kons-tl)
  (provide/contract [product (-> (sorted-list/gt -inf.0) number?)]))
])

The module provides a single function, @scheme[product] whose contract
indicates that it accepts sorted lists of numbers and produces
numbers. Using an ordinary flat contract for sorted lists, the product
function cannot avoid traversing having its entire argument be
traversed, since the contract checker will traverse it before the
function is called. As written above, however, when the product
function aborts the traversal of the list, the contract checking also
stops, since the @scheme[kons/dc] contract constructor generates a
lazy contract.}

@; ------------------------------------------------------------------------

@section{Attaching Contracts to Values}

@defform/subs[
#:literals (struct rename)
(provide/contract p/c-item ...)
([p/c-item
  (struct id ((id contract-expr) ...))
  (struct (id identifier) ((id contract-expr) ...))
  (rename orig-id id contract-expr)
  (id contract-expr)
  (code:line #:∃ exists-variables)
  (code:line #:exists exists-variables)]
 [exists-variables identifier
                   (identifier ...)])]{

Can only appear at the top-level of a @scheme[module]. As with
@scheme[provide], each @scheme[id] is provided from the module. In
addition, clients of the module must live up to the contract specified
by @scheme[contract-expr] for each export.

The @scheme[provide/contract] form treats modules as units of
blame. The module that defines the provided variable is expected to
meet the positive (co-variant) positions of the contract. Each module
that imports the provided variable must obey the negative
(contra-variant) positions of the contract.

Only uses of the contracted variable outside the module are
checked. Inside the module, no contract checking occurs.

The @scheme[rename] form of a @scheme[provide/contract] exports the
first variable (the internal name) with the name specified by the
second variable (the external name).

The @scheme[struct] form of a @scheme[provide/contract] clause
provides a structure definition, and each field has a contract that
dictates the contents of the fields. The struct definition must come
before the provide clause in the module's body. If the struct has a
parent, the second @scheme[struct] form (above) must be used, with the
first name referring to the struct itself and the second name
referring to the parent struct. Unlike @scheme[define-struct],
however, all of the fields (and their contracts) must be listed. The
contract on the fields that the sub-struct shares with its parent are
only used in the contract for the sub-struct's maker, and the selector
or mutators for the super-struct are not provided.

The @scheme[#:∃] and @scheme[#:exists] clauses define new abstract
contracts. The variables are bound in the remainder of the @scheme[provide/contract]
expression to new contracts that hide the values they accept and
ensure that the exported functions are treated parametrically.
}

@defform*/subs[
 [(with-contract blame-id (wc-export ...) free-var-list ... body ...+)
  (with-contract blame-id results-spec free-var-list ... body ...+)]
 ([wc-export
   (id contract-expr)]
  [result-spec
   (code:line #:result contract-expr)
   (code:line #:results (contract-expr ...))]
  [free-var-list
   (code:line #:freevars ([id contract-expr] ...))
   (code:line #:freevar id contract-expr)])]{
Generates a local contract boundary.

The first @scheme[with-contract] form cannot appear in expression position.
All names defined within the first @scheme[with-contract] form are
visible externally, but those names listed in the @scheme[wc-export]
list are protected with the corresponding contract.  The @scheme[body] of
the form allows definition/expression interleaving if its context does.

The second @scheme[with-contract] form must appear in expression position.
The final @scheme[body] expression should return the same number of values
as the number of contracts listed in the @scheme[result-spec], and each
returned value is contracted with its respective contract.  The sequence
of @scheme[body] forms is treated as for @scheme[let].

The @scheme[blame-id] is used for the positive positions of
contracts paired with exported @scheme[id]s.  Contracts broken
within the @scheme[with-contract] @scheme[body] will use the
@scheme[blame-id] for their negative position.

If a free-var-list is given, then any uses of the free variables
inside the @scheme[body] will be protected with contracts that
blame the context of the @scheme[with-contract] form for the positive
positions and the @scheme[with-contract] form for the negative ones.}

@defform*[[(define/contract id contract-expr free-var-list init-value-expr)
 (define/contract (head args) contract-expr free-var-list body ...+)]]{
Works like @scheme[define], except that the contract
@scheme[contract-expr] is attached to the bound value.  For the
definition of @scheme[head] and @scheme[args], see @scheme[define].
For the definition of @scheme[free-var-list], see @scheme[with-contract].

The @scheme[define/contract] form treats the individual definition as
a contract region. The definition itself is responsible for positive
(co-variant) positions of the contract and references to
@scheme[id] outside of the definition must meet the negative
positions of the contract. Since the contract boundary is
between the definition and the surrounding context, references to
@scheme[id] inside the @scheme[define/contract] form are not checked.

If a free-var-list is given, then any uses of the free variables
inside the @scheme[body] will be protected with contracts that
blame the context of the @scheme[define/contract] form for the positive
positions and the @scheme[define/contract] form for the negative ones.}

@defform*[[(define-struct/contract struct-id ([field contract-expr] ...)
                                   struct-option ...)
           (define-struct/contract (struct-id super-struct-id)
                                   ([field contract-expr] ...)
                                   struct-option ...)]]{
Works like @scheme[define-struct], except that the arguments to the constructor,
accessors, and mutators are protected by contracts.  For the definitions of
@scheme[field] and @scheme[struct-option], see @scheme[define-struct].

The @scheme[define-struct/contract] form only allows a subset of the
@scheme[struct-option] keywords: @scheme[#:mutable], @scheme[#:transparent],
@scheme[#:auto-value], @scheme[#:omit-define-syntaxes], @scheme[#:property] and
@scheme[#:omit-define-values].

@examples[#:eval (contract-eval)
(define-struct/contract fish ([color number?]))
(make-fish 5)
(make-fish #f)

(define-struct/contract (salmon fish) ([ocean symbol?]))
(make-salmon 5 'atlantic)
(make-salmon 5 #f)
(make-salmon #f 'pacific)
]}

@defform*[[(contract contract-expr to-protect-expr
                     positive-blame-expr negative-blame-expr)
           (contract contract-expr to-protect-expr 
                     positive-blame-expr negative-blame-expr
                     value-name-expr source-location-expr)]]{

The primitive mechanism for attaching a contract to a value. The
purpose of @scheme[contract] is as a target for the expansion of some
higher-level contract specifying form.

The @scheme[contract] expression adds the contract specified by
@scheme[contract-expr] to the value produced by
@scheme[to-protect-expr]. The result of a @scheme[contract] expression
is the result of the @scheme[to-protect-expr] expression, but with the
contract specified by @scheme[contract-expr] enforced on
@scheme[to-protect-expr].

The values of @scheme[positive-blame-expr] and @scheme[negative-blame-expr]
indicate how to assign blame for positive and negative positions of the contract
specified by @scheme[contract-expr].  They may be any value, and are formatted
as by @scheme[display] for purposes of contract violation error messages.

If specified, @scheme[value-name-expr] indicates a name for the protected value
to be used in error messages.  If not supplied, or if @scheme[value-name-expr]
produces @scheme[#f], no name is printed.  Otherwise, it is also formatted as by
@scheme[display].

If specified, @scheme[source-location-expr] indicates the source location
reported by contract violations.  The expession must produce a @scheme[srcloc]
structure, @tech{syntax object}, @scheme[#f], or a list or vector in the format
accepted by the third argument to @scheme[datum->syntax].

}

@; ------------------------------------------------------------------------

@section{Building New Contract Combinators}

@emph{@bold{Note:}
 The interface in this section is unstable and subject to change.}

Contracts are represented internally as functions that
accept information about the contract (who is to blame,
source locations, etc) and produce projections (in the
spirit of Dana Scott) that enforce the contract. A
projection is a function that accepts an arbitrary value,
and returns a value that satisfies the corresponding
contract. For example, a projection that accepts only
integers corresponds to the contract @scheme[(flat-contract
integer?)], and can be written like this:

@schemeblock[
(define int-proj
  (lambda (x)
    (if (integer? x)
        x
        (signal-contract-violation))))
]

As a second example, a projection that accepts unary functions
on integers looks like this:

@schemeblock[
(define int->int-proj
  (lambda (f)
    (if (and (procedure? f)
             (procedure-arity-includes? f 1))
        (lambda (x)
          (int-proj (f (int-proj x))))
        (signal-contract-violation))))
]

Although these projections have the right error behavior,
they are not quite ready for use as contracts, because they
do not accomodate blame, and do not provide good error
messages. In order to accomodate these, contracts do not
just use simple projections, but use functions that accept a
@deftech{blame object} encapsulating
the names of two parties that are the candidates for blame,
as well as a record of the source location where the
contract was established and the name of the contract. They
can then, in turn, pass that information
to @scheme[raise-blame-error] to signal a good error
message.

Here is the first of those two projections, rewritten for
use in the contract system:
@schemeblock[
(define (int-proj blame)
  (lambda (x)
    (if (integer? x)
        x
        (raise-blame-error
         blame
         val
         "expected <integer>, given: ~e"
         val))))
]
The new argument specifies who is to be blamed for
positive and negative contract violations.

Contracts, in this system, are always
established between two parties. One party provides some
value according to the contract, and the other consumes the
value, also according to the contract. The first is called
the ``positive'' person and the second the ``negative''. So,
in the case of just the integer contract, the only thing
that can go wrong is that the value provided is not an
integer. Thus, only the positive party can ever accrue
blame.  The @scheme[raise-blame-error] function always blames
the positive party.

Compare that to the projection for our function contract:

@schemeblock[
(define (int->int-proj blame)
  (let ([dom (int-proj (blame-swap blame))]
        [rng (int-proj blame)])
    (lambda (f)
      (if (and (procedure? f)
               (procedure-arity-includes? f 1))
          (lambda (x)
            (rng (f (dom x))))
          (raise-blame-error
           blame
           val
           "expected a procedure of one argument, given: ~e"
           val)))))
]

In this case, the only explicit blame covers the situation
where either a non-procedure is supplied to the contract, or
where the procedure does not accept one argument. As with
the integer projection, the blame here also lies with the
producer of the value, which is
why @scheme[raise-blame-error] is passed @scheme[blame] unchanged. 

The checking for the domain and range are delegated to
the @scheme[int-proj] function, which is supplied its
arguments in the first two line of
the @scheme[int->int-proj] function. The trick here is that,
even though the @scheme[int->int-proj] function always
blames what it sees as positive we can swap the blame parties by
calling @scheme[blame-swap] on the given @tech{blame object}, replacing
the positive party with the negative party and vice versa.

This is not just a cheap trick to get this example to work,
however. The reversal of the positive and the negative is a
natural consequence of the way functions behave. That is,
imagine the flow of values in a program between two
modules. First, one module defines a function, and then that
module is required by another. So, far the function itself
has to go from the original, providing module to the
requiring module. Now, imagine that the providing module
invokes the function, suppying it an argument. At this
point, the flow of values reverses. The argument is
travelling back from the requiring module to the providing
module! And finally, when the function produces a result,
that result flows back in the original
direction. Accordingly, the contract on the domain reverses
the positive and the negative blame parties, just like the flow
of values reverses.

We can use this insight to generalize the function contracts
and build a function that accepts any two contracts and
returns a contract for functions between them.

@schemeblock[
(define (make-simple-function-contract dom-proj range-proj)
  (lambda (blame)
    (let ([dom (dom-proj (blame-swap blame))]
          [rng (range-proj blame)])
      (lambda (f)
        (if (and (procedure? f)
                 (procedure-arity-includes? f 1))
            (lambda (x)
              (rng (f (dom x))))
            (raise-blame-error
             blame
             val
             "expected a procedure of one argument, given: ~e"
             val))))))
]

Projections like the ones described above, but suited to
other, new kinds of value you might make, can be used with
the contract library primitives below.

@deftogether[(
@defproc[(make-contract
          [#:name name any/c 'anonymous-contract]
          [#:first-order test (-> any/c any/c) (λ (x) #t)]
          [#:projection proj (-> blame? (-> any/c any/c))
           (λ (b)
             (λ (x)
               (if (test x)
                 x
                 (raise-blame-error
                  b x "expected <~a>, given: ~e" name x))))])
         contract?]
@defproc[(make-flat-contract
          [#:name name any/c 'anonymous-flat-contract]
          [#:first-order test (-> any/c any/c) (λ (x) #t)]
          [#:projection proj (-> blame? (-> any/c any/c))
           (λ (b)
             (λ (x)
               (if (test x)
                 x
                 (raise-blame-error
                  b x "expected <~a>, given: ~e" name x))))])
         flat-contract?]
)]{

These functions build simple procedure-based contracts and flat contracts,
respectively.  They both take the same set of three optional arguments: a name,
a first order predicate, and a blame-tracking projection.

The @scheme[name] argument is any value to be rendered using @scheme[display] to
describe the contract when a violation occurs.  The default name for simple
higher order contracts is @schemeresult[anonymous-contract], and for flat
contracts is @schemeresult[anonymous-flat-contract].

The first order predicate @scheme[test] can be used to determine which values
the contract applies to; usually this is the set of values for which the
contract fails immediately without any higher-order wrapping.  This test is used
by @scheme[contract-first-order-passes?], and indirectly by @scheme[or/c] to
determine which of multiple higher order contracts to wrap a value with.  The
default test accepts any value.

The projection @scheme[proj] defines the behavior of applying the contract.  It
is a curried function of two arguments: the first application accepts a blame
object, and the second accepts a value to protect with the contract.  The
projection must either produce the value, suitably wrapped to enforce any
higher-order aspects of the contract, or signal a contract violation using
@scheme[raise-blame-error].  The default projection produces an error when the
first order test fails, and produces the value unchanged otherwise.

Projections for flat contracts must fail precisely when the first order test
does, and must produce the input value unchanged otherwise.  Applying a flat
contract may result in either an application of the predicate, or the
projection, or both; therefore, the two must be consistent.  The existence of a
separate projection only serves to provide more specific error messages.  Most
flat contracts do not need to supply an explicit projection.

@defexamples[#:eval (contract-eval)
(define int/c
  (make-flat-contract #:name 'int/c #:first-order integer?))
(contract int/c 1 'positive 'negative)
(contract int/c "not one" 'positive 'negative)
(int/c 1)
(int/c "not one")
(define int->int/c
  (make-contract
   #:name 'int->int/c
   #:first-order
   (λ (x) (and (procedure? x) (procedure-arity-includes? x 1)))
   #:projection
   (λ (b)
     (let ([domain ((contract-projection int/c) (blame-swap b))]
           [range ((contract-projection int/c) b)])
       (λ (f)
         (if (and (procedure? f) (procedure-arity-includes? f 1))
           (λ (x) (range (f (domain x))))
           (raise-blame-error
            b f "expected a function of one argument, got: ~e" f)))))))
(contract int->int/c "not fun" 'positive 'negative)
(define halve (contract int->int/c (λ (x) (/ x 2)) 'positive 'negative))
(halve 2)
(halve 1)
(halve 1/2)
]

}

@defproc[(build-compound-type-name [c/s any/c] ...) any]{

Produces an S-expression to be used as a name
for a contract. The arguments should be either contracts or
symbols. It wraps parenthesis around its arguments and
extracts the names from any contracts it is supplied with.}

@defproc[(coerce-contract [id symbol?] [x any/c]) contract?]{

Converts a regular scheme value into an instance of a contract struct,
converting it according to the description of @tech{contracts}.

If @scheme[x] is not one of the coercable values,
@scheme[coerce-contract] signals an error, using the first argument in
the error message.}

@defproc[(coerce-contracts [id symbol?] [xs (listof any/c)]) (listof contract?)]{

Coerces all of the arguments in 'xs' into contracts (via
@scheme[coerce-contract/f]) and signals an error if any of them are not
contracts.  The error messages assume that the function named by
@scheme[id] got @scheme[xs] as its entire argument list.
}

@defproc[(coerce-flat-contract [id symbol?] [x any/c]) flat-contract?]{
  Like @scheme[coerce-contract], but requires the result
  to be a flat contract, not an arbitrary contract.
}

@defproc[(coerce-flat-contracts [id symbol?] [x (listof any/c)]) (listof/c flat-contract?)]{
  Like @scheme[coerce-contracts], but requires the results
  to be flat contracts, not arbitrary contracts.
}

@defproc[(coerce-contract/f [x any/c]) (or/c contract? #f)]{
  Like @scheme[coerce-contract], but returns @scheme[#f] if
  the value cannot be coerced to a contract.
}

@subsection{Blame Objects}

@defproc[(blame? [x any/c]) boolean?]{
This predicate recognizes @tech{blame objects}.
}

@deftogether[(
@defproc[(blame-positive [b blame?]) any/c]
@defproc[(blame-negative [b blame?]) any/c]
)]{
These functions produce printable descriptions of the current positive and
negative parties of a blame object.
}

@defproc[(blame-contract [b blame?]) any/c]{
This function produces a description of the contract associated with a blame
object (the result of @scheme[contract-name]).
}

@defproc[(blame-value [b blame?]) any/c]{
This function produces the name of the value to which the contract was applied,
or @scheme[#f] if no name was provided.
}

@defproc[(blame-source [b blame?]) srcloc?]{
This function produces the source location associated with a contract.  If no
source location was provided, all fields of the structure will contain
@scheme[#f].
}

@defproc[(blame-swap [b blame?]) blame?]{
This function swaps the positive and negative parties of a @tech{blame object}.
}

@deftogether[(
@defproc[(blame-original? [b blame?]) boolean?]
@defproc[(blame-swapped? [b blame?]) boolean?]
)]{

These functions report whether the current blame of a given blame object is the
same as in the original contract invocation (possibly of a compound contract
containing the current one), or swapped, respectively.  Each is the negation of
the other; both are provided for convenience and clarity.

}

@defproc[(raise-blame-error [b blame?] [x any/c] [fmt string?] [v any/c] ...)
         none/c]{

Signals a contract violation.  The first argument, @scheme[b], records the
current blame information, including positive and negative parties, the name of
the contract, the name of the value, and the source location of the contract
application.  The second argument, @scheme[x], is the value that failed to
satisfy the contract.  The remaining arguments are a format string,
@scheme[fmt], and its arguments, @scheme[v ...], specifying an error message
specific to the precise violation.

}

@defproc[(exn:fail:contract:blame? [x any/c]) boolean?]{
This predicate recognizes exceptions raised by @scheme[raise-blame-error].
}

@defproc[(exn:fail:contract:blame-object [e exn:fail:contract:blame?]) blame?]{
This accessor extracts the blame object associated with a contract violation.
}

@subsection{Contracts as structs}

@emph{@bold{Note:}
 The interface in this section is unstable and subject to change.}

@para{
The property @scheme[prop:contract] allows arbitrary structures to act as
contracts.  The property @scheme[prop:flat-contract] allows arbitrary structures
to act as flat contracts; @scheme[prop:flat-contract] inherits both
@scheme[prop:contract] and @scheme[prop:procedure], so flat contract structures
may also act as general contracts and as predicate procedures.
}

@deftogether[(
@defthing[prop:contract struct-type-property?]
@defthing[prop:flat-contract struct-type-property?]
)]{
These properties declare structures to be contracts or flat contracts,
respectively.  The value for @scheme[prop:contract] must be a @tech{contract
property} constructed by @scheme[build-contract-property]; likewise, the value
for @scheme[prop:flat-contract] must be a @tech{flat contract property}
constructed by @scheme[build-flat-contract-property].
}

@deftogether[(
@defproc[(build-flat-contract-property
          [#:name
           get-name
           (-> contract? any/c)
           (λ (c) 'anonymous-flat-contract)]
          [#:first-order
           get-first-order
           (-> contract? (-> any/c boolean?))
           (λ (c) (λ (x) #t))]
          [#:projection
           get-projection
           (-> contract? (-> blame? (-> any/c any/c)))
           (λ (c)
             (λ (b)
               (λ (x)
                 (if ((get-first-order c) x)
                   x
                   (raise-blame-error
                    b x "expected <~a>, given: ~e" (get-name c) x)))))]
         [#:stronger
	  stronger
	  (or/c (-> contract? contract? boolean?) #f)
	  #f]
         [#:generator
	  generator
	  (or/c (-> number? (listof (list any/c contract?)) any/c) #f)
	  #f])
         flat-contract-property?]
@defproc[(build-contract-property
          [#:name
           get-name
           (-> contract? any/c)
           (λ (c) 'anonymous-contract)]
          [#:first-order
           get-first-order
           (-> contract? (-> any/c boolean?))
           (λ (c) (λ (x) #t))]
          [#:projection
           get-projection
           (-> contract? (-> blame? (-> any/c any/c)))
           (λ (c)
             (λ (b)
               (λ (x)
                 (if ((get-first-order c) x)
                   x
                   (raise-blame-error
                    b x "expected <~a>, given: ~e" (get-name c) x)))))]
         [#:stronger
	  stronger
	  (or/c (-> contract? contract? boolean?) #f)
	  #f]
         [#:generator
	  generator
	  (or/c (-> number? (listof (list any/c contract?)) any/c) #f)
	  #f])
         contract-property?]
)]{

These functions build the arguments for @scheme[prop:contract] and
@scheme[prop:flat-contract], respectively.

A @deftech{contract property} specifies the behavior of a structure when used as
a contract.  It is specified in terms of five accessors: @scheme[get-name],
which produces a description to @scheme[write] as part of a contract violation;
@scheme[get-first-order], which produces a first order predicate to be used by
@scheme[contract-first-order-passes?]; @scheme[get-projection], which
produces a blame-tracking projection defining the behavior of the contract;
@scheme[stronger], which is a predicate that determines if one contract this contract
(passed in the first argument) is stronger than some other contract (passed in the second argument);
and @scheme[generator], which makes a random value that matches the contract,
given a size bound and an environment from which to draw interesting values.

These accessors are passed as (optional) keyword arguments to
@scheme[build-contract-property], and are applied to instances of the
appropriate structure type by the contract system.  Their results are used
analogously to the arguments of @scheme[make-contract].

A @deftech{flat contract property} specifies the behavior of a structure when
used as a flat contract.  It is specified using
@scheme[build-flat-contract-property], and accepts exactly the same set of
arguments as @scheme[build-contract-property].  The only difference is that the
projection accessor is expected not to wrap its argument in a higher order
fashion, analogous to the constraint on projections in
@scheme[make-flat-contract].

}

@deftogether[(
@defproc[(contract-property? [x any/c]) boolean?]
@defproc[(flat-contract-property? [x any/c]) boolean?]
)]{
These predicates detect whether a value is a @tech{contract property} or a
@tech{flat contract property}, respectively.
}

@; ------------------------------------------------------------------------

@section{Contract Utilities}

@defproc[(contract? [v any/c]) boolean?]{

Returns @scheme[#t] if its argument is a contract (i.e., constructed
with one of the combinators described in this section or a value that
can be used as a contract) and @scheme[#f] otherwise.}

@defproc[(flat-contract? [v any/c]) boolean?]{

Returns @scheme[#t] when its argument is a contract that can be
checked immediately (unlike, say, a function contract). 

For example,
@scheme[flat-contract] constructs flat contracts from predicates, and
symbols, booleans, numbers, and other ordinary Scheme values
(that are defined as @tech{contracts}) are also
flat contracts.}

@defproc[(flat-contract-predicate [v flat-contract?])
         (any/c . -> . any/c)]{

Extracts the predicate from a flat contract.}

@defproc[(value-contract [v has-contract?]) contract?]{
  Returns the contract attached to @scheme[v], if recorded.
  Otherwise it returns @scheme[#f].
}

@defproc[(has-contract? [v any/c]) boolean?]{
  Returns @scheme[#t] if @scheme[v] is a value that
  has a recorded contract attached to it.
}

@defproc[(contract-first-order-passes? [contract contract?]
                                       [v any/c])
         boolean?]{

Returns a boolean indicating if the first-order tests
of @scheme[contract] pass for @scheme[v].

If it returns @scheme[#f], the contract is guaranteed not to
hold for that value; if it returns @scheme[#t], the contract
may or may not hold. If the contract is a first-order
contract, a result of @scheme[#t] guarantees that the
contract holds.}

@defproc[(contract-name [c contract?]) any/c]{
Produces the name used to describe the contract in error messages.
}

@defproc[(contract-first-order [c contract?]) (-> any/c boolean?)]{
Produces the first order test used by @scheme[or/c] to match values to higher
order contracts.
}

@defproc[(contract-projection [c contract?]) (-> blame? (-> any/c any/c))]{
Produces the projection defining a contract's behavior on protected values.
}

@defproc[(make-none/c [sexp-name any/c]) contract?]{

Makes a contract that accepts no values, and reports the
name @scheme[sexp-name] when signaling a contract violation.}


@defparam[current-blame-format
          proc 
          (-> blame? any/c string? string?)]{

This is a parameter that is used when constructing a
contract violation error. Its value is procedure that
accepts three arguments: 
@itemize[
@item{the blame object for the violation,}
@item{the value that the contract applies to, and}
@item{a message indicating the kind of violation.}]
The procedure then
returns a string that is put into the contract error
message. Note that the value is often already included in
the message that indicates the violation.

@defexamples[#:eval (contract-eval)
(define (show-blame-error blame value message)
  (string-append
   "Contract Violation!\n"
   (format "Guilty Party: ~a\n" (blame-positive blame))
   (format "Innocent Party: ~a\n" (blame-negative blame))
   (format "Contracted Value Name: ~a\n" (blame-value blame))
   (format "Contract Location: ~s\n" (blame-source blame))
   (format "Contract Name: ~a\n" (blame-contract blame))
   (format "Offending Value: ~s\n" value)
   (format "Offense: ~a\n" message)))
[current-blame-format show-blame-error]
(define/contract (f x)
  (-> integer? integer?)
  (/ x 2))
(f 2)
(f 1)
(f 1/2)
]

}


@defform[(recursive-contract contract-expr)]{

Delays the evaluation of its argument until the contract is checked,
making recursive contracts possible.}


@defform[(opt/c contract-expr)]{

This optimizes its argument contract expression by
traversing its syntax and, for known contract combinators,
fuses them into a single contract combinator that avoids as
much allocation overhad as possible. The result is a
contract that should behave identically to its argument,
except faster (due to the less allocation).}


@defform[(define-opt/c (id id ...) expr)]{

This defines a recursive contract and simultaneously
optimizes it. Semantically, it behaves just as if
the @scheme[-opt/c] were not present, defining a function on
contracts (except that the body expression must return a
contract). But, it also optimizes that contract definition,
avoiding extra allocation, much like @scheme[opt/c] does.

For example, 

@schemeblock[
(define-contract-struct bt (val left right))

(define-opt/c (bst-between/c lo hi)
  (or/c null?
        (bt/c [val (real-in lo hi)]
              [left (val) (bst-between/c lo val)]
              [right (val) (bst-between/c val hi)])))

(define bst/c (bst-between/c -inf.0 +inf.0))
]

defines the @scheme[bst/c] contract that checks the binary
search tree invariant. Removing the @scheme[-opt/c] also
makes a binary search tree contract, but one that is
(approximately) 20 times slower.}

