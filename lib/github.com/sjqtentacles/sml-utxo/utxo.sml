structure Utxo :> UTXO =
struct
  type txid = string
  type outpoint = { txid : txid, index : int }
  type txout = { value : IntInf.int, scriptPubKey : string }
  type txin  = { prevout : outpoint, scriptSig : string, sequence : Word32.word }
  type tx = { version  : Word32.word
            , inputs   : txin list
            , outputs  : txout list
            , locktime : Word32.word }

  exception DoubleSpend
  exception Overspend
  exception InvalidTx

  (* UTXO set as sorted association list: (outpoint * txout) list *)
  type utxo = (outpoint * txout) list

  fun cmpOutpoint (a : outpoint, b : outpoint) =
    let val c = String.compare (#txid a, #txid b)
    in if c <> EQUAL then c else Int.compare (#index a, #index b) end

  fun empty () : utxo = []

  fun lookup (set : utxo) (pt : outpoint) : txout option =
    case List.find (fn (k, _) => cmpOutpoint (k, pt) = EQUAL) set of
      NONE => NONE
    | SOME (_, v) => SOME v

  fun size (set : utxo) : int = List.length set

  fun insertSorted (k : outpoint) (v : txout) [] = [(k, v)]
    | insertSorted k v ((k2, v2) :: rest) =
        case cmpOutpoint (k, k2) of
          LESS    => (k, v) :: (k2, v2) :: rest
        | EQUAL   => (k, v) :: rest
        | GREATER => (k2, v2) :: insertSorted k v rest

  fun removeKey (k : outpoint) [] = raise DoubleSpend
    | removeKey k ((k2, v2) :: rest) =
        if cmpOutpoint (k, k2) = EQUAL then rest
        else (k2, v2) :: removeKey k rest

  fun simpleHash (s : string) : string =
    let
      val n = String.size s
      fun go i acc =
        if i >= n then acc
        else go (i + 1) (Word32.+ (Word32.* (acc, 0w31),
                                   Word32.fromInt (Char.ord (String.sub (s, i)))))
    in
      Word32.toString (go 0 0w5381)
    end

  fun serializeOutpoint (pt : outpoint) =
    #txid pt ^ ":" ^ Int.toString (#index pt)

  fun txid (tx : tx) : txid =
    let
      val inStr  = String.concat (List.map (fn i => serializeOutpoint (#prevout i)) (#inputs tx))
      val outStr = String.concat (List.map (fn outp => IntInf.toString (#value outp)) (#outputs tx))
    in
      simpleHash (inStr ^ outStr)
    end

  fun sumValues (outs : txout list) : IntInf.int =
    List.foldl (fn (outp, acc) => IntInf.+ (acc, #value outp)) (IntInf.fromInt 0) outs

  fun apply (set : utxo) (tx : tx) : utxo =
    let
      val isCoinbase = List.null (#inputs tx)
    in
      if isCoinbase
      then
        let
          val newTxid = txid tx
          fun addOut (outp, (i, acc)) =
            let val pt = {txid = newTxid, index = i}
            in (i + 1, insertSorted pt outp acc) end
          val (_, newSet) = List.foldl addOut (0, set) (#outputs tx)
        in
          newSet
        end
      else
        let
          fun spendInput (inp, (acc, inVal)) =
            let
              val pt = #prevout inp
              val txoutVal = case lookup acc pt of
                NONE        => raise DoubleSpend
              | SOME txoutp => #value txoutp
              val acc' = removeKey pt acc
            in
              (acc', IntInf.+ (inVal, txoutVal))
            end
          val (set', inputTotal) =
            List.foldl spendInput (set, IntInf.fromInt 0) (#inputs tx)
          val outputTotal = sumValues (#outputs tx)
          val () = if IntInf.< (inputTotal, outputTotal) then raise Overspend else ()
          val newTxid = txid tx
          fun addOut (outp, (i, acc)) =
            let val pt = {txid = newTxid, index = i}
            in (i + 1, insertSorted pt outp acc) end
          val (_, finalSet) = List.foldl addOut (0, set') (#outputs tx)
        in
          finalSet
        end
    end
end
