# sml-utxo

[![CI](https://github.com/sjqtentacles/sml-utxo/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-utxo/actions/workflows/ci.yml)

Bitcoin-style Unspent Transaction Output (UTXO) model in pure Standard ML:
transactions, a UTXO set with apply/spend semantics, structural validation,
fees, balances, and block application.

## API

```sml
type txid     = string
type outpoint = { txid : txid, index : int }
type txout    = { value : IntInf.int, scriptPubKey : string }
type txin     = { prevout : outpoint, scriptSig : string, sequence : Word32.word }
type tx       = { version : Word32.word, inputs : txin list
                , outputs : txout list, locktime : Word32.word }

exception DoubleSpend
exception Overspend
exception InvalidTx of string

type utxo
val empty       : unit -> utxo
val lookup      : utxo -> outpoint -> txout option
val member      : utxo -> outpoint -> bool
val size        : utxo -> int
val toList      : utxo -> (outpoint * txout) list
val outpointsOf : utxo -> outpoint list
val totalValue  : utxo -> IntInf.int
val balance     : utxo -> (string -> bool) -> IntInf.int

val txid          : tx -> txid
val validate      : tx -> unit
val fee           : utxo -> tx -> IntInf.int
val apply         : utxo -> tx -> utxo
val tryApply      : utxo -> tx -> utxo option
val applyBlock    : utxo -> tx list -> utxo
val tryApplyBlock : utxo -> tx list -> utxo option
```

## Usage

```sml
val u0 = Utxo.empty ()

val coinbase =
  { version = 0w1, inputs = []
  , outputs = [{value = IntInf.fromInt 5000, scriptPubKey = "p2pk"}]
  , locktime = 0w0 }
val u1   = Utxo.apply u0 coinbase
val cbId = Utxo.txid coinbase

(* spend the coinbase: 4000 to a recipient, 500 change; fee = 500 *)
val spendTx =
  { version = 0w1
  , inputs  = [{ prevout = {txid = cbId, index = 0}, scriptSig = "", sequence = 0wxFFFFFFFF }]
  , outputs = [ {value = IntInf.fromInt 4000, scriptPubKey = "bob"}
              , {value = IntInf.fromInt  500, scriptPubKey = "p2pk"} ]
  , locktime = 0w0 }
val theFee = Utxo.fee u1 spendTx          (* 500 *)
val u2     = Utxo.apply u1 spendTx

val n      = Utxo.size u2                  (* 2 *)
val total  = Utxo.totalValue u2            (* 4500 *)
val mine   = Utxo.balance u2 (fn s => s = "p2pk")   (* 500 *)

(* apply a whole block atomically *)
val u3 = Utxo.applyBlock u0 [coinbase, spendTx]
```

## Validation

`validate` (run automatically by `apply`) raises `InvalidTx` for:

- **empty output list**,
- **non-positive output values**,
- **duplicate inputs** (the same outpoint spent twice in one tx).

Spending a missing/already-spent output raises `DoubleSpend`; spending less than
you consume is fine (the difference is the fee), but spending *more* raises
`Overspend`. Coinbase transactions (no inputs) are allowed and have zero fee.

`txid` hashes the inputs **and** each output's value and `scriptPubKey`, so two
transactions that differ only in recipient get distinct ids.

## Example

`make example` builds and runs [`examples/demo.sml`](examples/demo.sml):

```
$ make example
Coinbase transaction:
  txid = B395D97B
  utxo set size = 1
  output 0 value = 5000

Spend transaction:
  txid = 5140B22B
  utxo set size = 1
  coinbase output spent = true
  new output 0 value = 4000

Double-spend attempt of the spent coinbase output:
  result = rejected (DoubleSpend)
```

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-utxo
smlpkg sync
```

## Building and testing

```sh
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
make example     # build + run the demo
make clean
```

## License

MIT
