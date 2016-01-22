(in-package :cl-user)
(defpackage mito-test.migration.postgres
  (:use #:cl
        #:prove
        #:mito
        #:mito.migration
        #:mito-test.util))
(in-package :mito-test.migration.postgres)

(plan nil)

(setf *connection* (connect-to-testdb :postgres))

(when (find-class 'tweets nil)
  (setf (find-class 'tweets) nil))
(execute-sql "DROP TABLE IF EXISTS tweets")

(subtest "first definition (no explicit primary key)"
  (defclass tweets ()
    ((user :col-type (:varchar 128)
           :accessor tweet-user))
    (:metaclass dao-table-class))
  (execute-sql (table-definition 'tweets))

  (is (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
      '(nil nil nil nil nil)
      "No migration at first")

  (defclass tweets ()
    ((user :col-type (:varchar 128)
           :accessor tweet-user))
    (:metaclass dao-table-class)
    (:table-name "tweets"))

  (is (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
      '(nil nil nil nil nil)
      "No migration at first"))

(subtest "redefinition with :auto-pk nil"
  (defclass tweets ()
    ((user :col-type (:varchar 128)
           :accessor tweet-user))
    (:metaclass dao-table-class)
    (:auto-pk nil))

  (destructuring-bind (add-columns
                       drop-columns
                       change-columns
                       add-indices
                       drop-indices)
      (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
    (is add-columns nil
        "No columns to add")
    (is (sxql:yield drop-columns) "ALTER TABLE tweets DROP COLUMN %oid"
        "Drop column %oid")
    (is change-columns nil
        "No columns to change")
    (is add-indices nil
        "No indices to add")
    (is drop-indices nil
        "No indices to drop")))

(subtest "redefinition (with explicit primary key)"
  (defclass tweets ()
    ((id :col-type :serial
         :primary-key t
         :reader tweet-id)
     (status :col-type :text
             :accessor tweet-status)
     (user :col-type (:varchar 128)
           :accessor tweet-user))
    (:metaclass dao-table-class))

  (destructuring-bind (add-columns
                       drop-columns
                       change-columns
                       add-indices
                       drop-indices)
      (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
    (is (sxql:yield add-columns) "ALTER TABLE tweets ADD COLUMN id serial NOT NULL PRIMARY KEY, ADD COLUMN status text"
        "Add id and status")
    (is (sxql:yield drop-columns) "ALTER TABLE tweets DROP COLUMN %oid"
        "Drop %oid")
    (is change-columns nil
        "No columns to change")
    (is add-indices nil
        "No indices to add (added when adding column)")
    (is drop-indices nil
        "No indices to drop (will remove when dropping column)"))

  (migrate-table (find-class 'tweets))

  (is (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
      '(nil nil nil nil nil)
      "No migration after migrating"))

(subtest "redefinition"
  (defclass tweets ()
    ((id :col-type :serial
         :primary-key t
         :reader tweet-id)
     (user :col-type (:varchar 64)
           :accessor tweet-user)
     (created-at :col-type (:char 8)))
    (:metaclass dao-table-class))

  (destructuring-bind (add-columns
                       drop-columns
                       change-columns
                       add-indices
                       drop-indices)
      (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
    (is (sxql:yield add-columns) "ALTER TABLE tweets ADD COLUMN created_at character(8)")
    (is (sxql:yield drop-columns) "ALTER TABLE tweets DROP COLUMN status")
    (is (format nil "~{~A~^~%~}"
                (mapcar #'sxql:yield change-columns))
        "ALTER TABLE tweets ALTER COLUMN user TYPE character varying(64)")
    (is add-indices nil)
    (is drop-indices nil))

  (migrate-table (find-class 'tweets))

  (is (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
      '(nil nil nil nil nil)
      "No migration after migrating"))

(subtest "redefinition (modifying the column type)"
  (defclass tweets ()
    ((id :col-type :serial
         :primary-key t
         :reader tweet-id)
     (user :col-type (:varchar 128)
           :accessor tweet-user)
     (created-at :col-type (:char 8)))
    (:metaclass dao-table-class))

  (destructuring-bind (add-columns
                       drop-columns
                       change-columns
                       add-indices
                       drop-indices)
      (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
    (is add-columns nil)
    (is drop-columns nil)
    (is (format nil "~{~A~^~%~}"
                (mapcar #'sxql:yield change-columns))
        "ALTER TABLE tweets ALTER COLUMN user TYPE character varying(128)")
    (is add-indices nil)
    (is drop-indices nil))

  (migrate-table (find-class 'tweets))

  (is (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
      '(nil nil nil nil nil)
      "No migration after migrating"))

(subtest "redefinition of primary key"
  (defclass tweets ()
    ((id :col-type :bigserial
         :primary-key t
         :reader tweet-id)
     (user :col-type (:varchar 128)
           :accessor tweet-user)
     (created-at :col-type (:char 8)))
    (:metaclass dao-table-class))

  (destructuring-bind (add-columns
                       drop-columns
                       change-columns
                       add-indices
                       drop-indices)
      (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
    (is add-columns nil)
    (is drop-columns nil)
    (is (format nil "~{~A~^~%~}"
                (mapcar #'sxql:yield change-columns))
        "ALTER TABLE tweets ALTER COLUMN id TYPE bigint")
    (is add-indices nil)
    (is drop-indices nil))

  (migrate-table (find-class 'tweets))

  (is (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
      '(nil nil nil nil nil)
      "No migration after migrating"))

(subtest "add :unique-keys"
  (defclass tweets ()
    ((id :col-type :bigserial
         :primary-key t
         :reader tweet-id)
     (user :col-type (:varchar 128)
           :accessor tweet-user)
     (created-at :col-type (:char 8)))
    (:metaclass dao-table-class)
    (:unique-keys (user created-at)))

  (destructuring-bind (add-columns
                       drop-columns
                       change-columns
                       add-indices
                       drop-indices)
      (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
    (is add-columns nil)
    (is drop-columns nil)
    (is change-columns nil)
    (is (length add-indices) 1)
    (like (sxql:yield (first add-indices)) "^CREATE UNIQUE INDEX [^ ]+ ON tweets \\(created_at, user\\)$")
    (is drop-indices nil))

  (migrate-table (find-class 'tweets))

  (is (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
      '(nil nil nil nil nil)
      "No migration after migrating"))

(subtest "modify :unique-keys"
  (defclass tweets ()
    ((id :col-type :bigserial
         :primary-key t
         :reader tweet-id)
     (user :col-type (:varchar 128)
           :accessor tweet-user)
     (created-at :col-type (:char 8)))
    (:metaclass dao-table-class)
    (:unique-keys (id user created-at)))

  (destructuring-bind (add-columns
                       drop-columns
                       change-columns
                       add-indices
                       drop-indices)
      (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
    (is add-columns nil)
    (is drop-columns nil)
    (is change-columns nil)
    (is (length add-indices) 1)
    (like (sxql:yield (first add-indices)) "^CREATE UNIQUE INDEX [^ ]+ ON tweets \\(created_at, id, user\\)$")
    (is (length drop-indices) 1)
    (like (sxql:yield (first drop-indices)) "^DROP INDEX [^ ]+$"))

  (migrate-table (find-class 'tweets))

  (is (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
      '(nil nil nil nil nil)
      "No migration after migrating"))

(subtest "delete :unique-keys and add :keys"
  (defclass tweets ()
    ((id :col-type :bigserial
         :primary-key t
         :reader tweet-id)
     (user :col-type (:varchar 128)
           :accessor tweet-user)
     (created-at :col-type (:char 8)))
    (:metaclass dao-table-class)
    (:keys (user created-at)))

  (destructuring-bind (add-columns
                       drop-columns
                       change-columns
                       add-indices
                       drop-indices)
      (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
    (is add-columns nil)
    (is drop-columns nil)
    (is change-columns nil)
    (is (length add-indices) 1)
    (like (sxql:yield (first add-indices)) "^CREATE INDEX [^ ]+ ON tweets \\(created_at, user\\)$")
    (is (length drop-indices) 1)
    (like (sxql:yield (first drop-indices)) "^DROP INDEX [^ ]+$"))

  (migrate-table (find-class 'tweets))

  (is (mito.migration::migration-expressions-for-others (find-class 'tweets) :postgres)
      '(nil nil nil nil nil)
      "No migration after migrating"))

(finalize)

(disconnect-toplevel)
