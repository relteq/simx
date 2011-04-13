def create_table? t, db = DB, &bl
  db.table_exists? t or db.create_table t, &bl
end

# Used to generate IDs that are unique across all tables that use it.
# The tables include all those with composite primary key (node, link...).
# All rows but the last can be deleted at any time.
# Distinctly created (not copied) entities remain distinct
# in the database, so that they can be copied and pasted alongside
# each other.
def create_next_uniq_id_table db = DB
  create_table? :next_uniq_id, db do
    primary_key :id
  end
end

def get_uniq_id db = DB
  uniq_id = db[:next_uniq_id].insert
  db[:next_uniq_id].where(:id => uniq_id - 1).delete
  uniq_id
end
