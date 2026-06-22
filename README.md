# sml-utxo

Bitcoin-style Unspent Transaction Output (UTXO) model in pure Standard ML

## Installation

```
smlpkg add github.com/sjqtentacles/sml-utxo
smlpkg sync
```

## Usage

```sml
(* Start with an empty UTXO set *)
val u0 = Utxo.empty ()

(* Create and apply a coinbase transaction *)
val coinbase =
  { version  = 0w1
  , inputs   = []
  , outputs  = [{value = IntInf.fromInt 5000, scriptPubKey = "p2pk"}]
  , locktime = 0w0
  }
val u1    = Utxo.apply u0 coinbase
val cbId  = Utxo.txid coinbase

(* Spend the coinbase output *)
val spendTx =
  { version  = 0w1
  , inputs   = [{ prevout   = {txid = cbId, index = 0}
               , scriptSig = ""
               , sequence  = 0wxFFFFFFFF }]
  , outputs  = [{value = IntInf.fromInt 4900, scriptPubKey = "p2pk2"}]
  , locktime = 0w0
  }
val u2 = Utxo.apply u1 spendTx

(* Query the UTXO set *)
val SOME out = Utxo.lookup u2 {txid = Utxo.txid spendTx, index = 0}
val n        = Utxo.size u2   (* 1 *)
```

## Example

`make example` builds and runs [`examples/demo.sml`](examples/demo.sml), which
builds a small UTXO set from a fixed coinbase, spends it, and reports
transaction ids, set sizes, output values, and double-spend rejection:

```
$ make example
Coinbase transaction:
  txid = 284CDC60
  utxo set size = 1
  output 0 value = 5000

Spend transaction:
  txid = 7EB71BC5
  utxo set size = 1
  coinbase output spent = true
  new output 0 value = 4000

Double-spend attempt of the spent coinbase output:
  result = rejected (DoubleSpend)
```

## Testing

```
make test       # MLton
make test-poly  # Poly/ML
make example    # build + run the demo
```

## License

MIT
