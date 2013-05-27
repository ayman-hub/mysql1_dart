part of sqljocky;

/**
 * Start a transaction by using [ConnectionPool.startTransaction]. Once a transaction
 * is started it retains its connection until the transaction is committed or rolled
 * back. You must use the [commit] and [rollback] methods to do this, otherwise
 * the connection will not be released back to the pool.
 */
class Transaction extends Object with ConnectionHelpers {
  _Connection _cnx;
  ConnectionPool _pool;
  bool _finished;
  
  // TODO: maybe give the connection a link to its transaction?

  Transaction._internal(this._cnx, this._pool) : _finished = false;
  
  /**
   * Commits the transaction and released the connection. An error will be thrown
   * if any queries are executed after calling commit.
   */
  Future commit() {
    _checkFinished();
    _finished = true;
    var c = new Completer();
  
    var handler = new _QueryStreamHandler("commit");
    _cnx.processHandler(handler)
      .then((results) {
        _releaseReuseComplete(_cnx, c, results);
      })
      .catchError((e) {
        c.completeError(e);
      });

    return c.future;
  }
  
  /**
   * Rolls back the transaction and released the connection. An error will be thrown
   * if any queries are executed after calling rollback.
   */
  Future rollback() {
    _checkFinished();
    _finished = true;
    var c = new Completer();
  
    var handler = new _QueryStreamHandler("rollback");
    _cnx.processHandler(handler)
      .then((results) {
        _releaseReuseComplete(_cnx, c, results);
      })
      .catchError((e) {
        c.completeError(e);
      });

    return c.future;
  }

  Future<Results> query(String sql) {
    _checkFinished();
    var handler = new _QueryStreamHandler(sql);
    return _cnx.processHandler(handler);
  }
  
  //TODO: should the query get closed when the transaction is closed?
  //TODO: it isn't valid any more, at least
  Future<Query> prepare(String sql) {
    _checkFinished();
    var query = new Query._forTransaction(new _TransactionPool(_cnx), _cnx, sql);
    var c = new Completer<Query>();
    query._prepare()
      .then((preparedQuery) {
        c.complete(query);
      })
      .catchError((e) {
        c.completeError(e);
      });
    return c.future;
  }
  
  Future<Results> prepareExecute(String sql, List<dynamic> parameters) {
    _checkFinished();
    var c = new Completer<Results>();
    prepare(sql)
      .then((query) {
        query.execute()
          .then((results) {
          //TODO is it right to close here? Query might still be running
            query.close();
            c.complete(results);
          })
          .catchError((e) {
            c.completeError(e);
          });
      })
      .catchError((e) {
        c.completeError(e);
      });
    return c.future;
  }

  void _checkFinished() {
    if (_finished) {
      throw new StateError("Transaction has already finished");
    }
  }

  _releaseConnection(_Connection cnx) {
    _pool._releaseConnection(cnx);
  }

  _reuseConnection(_Connection cnx) {
    _pool._reuseConnection(cnx);
  }
}

class _TransactionPool extends ConnectionPool {
  final _Connection cnx;
  
  _TransactionPool(this.cnx);
  
  Future<_Connection> _getConnection() {
    var c = new Completer<_Connection>();
    c.complete(cnx);
    return c.future;
  }
  
  _releaseConnection(_Connection cnx) {
  }
  
  _reuseConnection(_Connection cnx) {
  }
}