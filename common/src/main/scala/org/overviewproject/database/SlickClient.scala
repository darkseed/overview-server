package org.overviewproject.database

import scala.concurrent.{ ExecutionContext, Future, blocking }
import scala.slick.jdbc.JdbcBackend.Session

trait SlickClient {
  /** Runs stuff with a Slick Session, blocking.
    *
    * There is no scala.concurrent.blocking() around this call; you should add
    * your own.
    */
  def blockingDb[A](block: Session => A): A

  /** Runs stuff with a Slick Session, in a Future.
    *
    * The default implementation calls blockingDb(), surrounding it with
    * scala.concurrent.blocking().
    */
  def db[A](block: Session => A)(implicit executor: ExecutionContext): Future[A] = {
    Future(blocking(blockingDb(block)))
  }

  // [Adam, 2015-02-26] I much prefer this call style
  def withTransaction[A](session: Session)(block: => A): A = {
    val connection = session.conn
    
    if (connection.getAutoCommit) {
      connection.setAutoCommit(false)
      
      val r = block
      
      connection.commit
      connection.setAutoCommit(true)
      r
    }
    else block
  }
  
  def withTransaction[A](block: Session => A)(implicit session: Session): A = {
    withTransaction(session){ block(session) }
  }
}
