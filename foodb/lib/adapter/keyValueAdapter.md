Key Value adapter

seq
- key: auto increment
- value: id

doc history
- key: id
- value: List<doc + seq>

view(all_doc) non delete winner doc
- key: id
- value: doc + seq

other_view()
- TODO

[] PUT /db/doc
1. add new seq
2. add doc + seq + rev into history
3. decide winner: https://hasura.io/blog/couchdb-style-conflict-resolution-rxdb-hasura/
4. regenerate view (winner view aka _all_docs)

[] GET /db/doc
- query doc history, return winner

[] GET /db/doc with leafnode / conflict
- query doc history
- sort doc by longest revisions
- remove all parent doc inside revisions
- the remain, pick the longest as new leaf node

[] GET /db/_all_docs
- query winner view

[] DELETE /db/doc
1. check exist in doc history
2. add new seq
3. add doc + _deleted + seq + rev into history
4. regenerate view

[] GET /db/_changes since 2 with limit 1, seq_interval
1. start from since
2. while response.length < limit not reach or not the last seq
  1. fetch next N(seq_interval) seq
  2. group seq by id
  3. compare doc winner seq with seq id, if match
    1. add to response
    2. depends on stlye and conflict, return doc or compute leaf node from doc (see GET /db/doc)
  4. else
    1. ignore