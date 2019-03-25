{:ok, db} = :rocksdb.open('#{__DIR__}/rocks.test', create_if_missing: true)

:rocksdb.put(db, Sortable.encode(["folder", 2018, 1, 1, "key-1"]), "value-1", [])
:rocksdb.put(db, Sortable.encode(["folder", 2018, 1, 2, "key-2"]), "value-2", [])
:rocksdb.put(db, Sortable.encode(["folder", 2019, 3, 1, "key-3"]), "value-3", [])

# retrieve everyhing in 2018

{:ok, iterator} =
  :rocksdb.iterator(db,
    iterate_lower_bound: Sortable.encode(["folder", 2018]),
    iterate_upper_bound: Sortable.encode(["folder", 2019])
  )

{:ok, _, "value-1"} = :rocksdb.iterator_move(iterator, :first)
{:ok, _, "value-2"} = :rocksdb.iterator_move(iterator, :next)
{:error, :invalid_iterator} = :rocksdb.iterator_move(iterator, :next)

:rocksdb.iterator_close(iterator)
