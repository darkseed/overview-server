package controllers.backend

import scala.concurrent.Future

import org.overviewproject.models.DocumentSet
import org.overviewproject.models.tables.{DocumentSetUsers,DocumentSets}

trait DocumentSetBackend {
  /** Returns a single DocumentSet. */
  def show(documentSetId: Long): Future[Option[DocumentSet]]

  /** Returns the number of document sets owned or viewed by the given user. */
  def countByUserEmail(userEmail: String): Future[Int]
}

trait DbDocumentSetBackend extends DocumentSetBackend { self: DbBackend =>
  override def show(documentSetId: Long) = firstOption(DbDocumentSetBackend.byId(documentSetId))

  override def countByUserEmail(userEmail: String) = db { session =>
    import org.overviewproject.database.Slick.simple._
    DbDocumentSetBackend.countByUserEmail(userEmail).run(session)
  }
}

object DbDocumentSetBackend {
  import org.overviewproject.database.Slick.simple._

  private lazy val byId = Compiled { (documentSetId: Column[Long]) =>
    DocumentSets.filter(_.id === documentSetId)
  }

  private lazy val countByUserEmail = Compiled { (userEmail: Column[String]) =>
    DocumentSetUsers
      .filter(_.userEmail === userEmail)
      .length
  }
}

object DocumentSetBackend extends DbDocumentSetBackend with DbBackend
