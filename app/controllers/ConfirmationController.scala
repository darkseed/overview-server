package controllers

import play.api.mvc.Action
import play.api.Logger

import controllers.auth.{OptionallyAuthorizedAction,AuthResults}
import controllers.auth.Authorities.anyUser
import models.OverviewDatabase
import models.{IntercomConfiguration, MailChimp, OverviewUser}
import models.Session
import models.orm.stores.{SessionStore,UserStore}

object ConfirmationController extends Controller {
  private val m = views.Magic.scopedMessages("controllers.ConfirmationController")

  /** Prompts for a confirmation token.
    */
  def index(email: String) = Action { implicit request =>
    Ok(views.html.Confirmation.index(email))
  }

  /** Confirms a confirmation token.
    *
    * Normally, there would be a POST update for confirming. However, we want
    * to confirm via email link, so it must be a GET.
    *
    * There are two possible outcomes:
    *
    * 1) The user is found
    */
  def show(token: String) = OptionallyAuthorizedAction(anyUser) { implicit request =>
    request.user match {
      case Some(user) => Redirect(routes.WelcomeController.show)
      case None => OverviewUser.findByConfirmationToken(token) match {
        case Some(u) => {
          val session = OverviewDatabase.inTransaction {
            val savedUser = OverviewUser(UserStore.insertOrUpdate(u.confirm.toUser))
            val ret = Session(savedUser.id, request.remoteAddress)
            SessionStore.insertOrUpdate(ret)
            ret
          }

          if (u.requestedEmailSubscription) {
            MailChimp.subscribe(u.email).getOrElse(Logger.info(s"Did not attempt requested subscription for ${u.email}"))
          }

          val result = AuthResults.loginSucceeded(request, session)

          // We have an Intercom welcome message -- see
          // https://www.pivotaltracker.com/story/show/70209172
          //
          // So if we're using Intercom, don't flash a welcome.
          //
          // This is untested because the most likely source of user-facing
          // error is a change to our Intercom settings, which our test suite
          // can't control.
          IntercomConfiguration.settingsForUser(u.toUser) match {
            case Some(_) =>
              result.flashing(
                "event" -> "confirmation-update"
              )
            case None =>
              result.flashing(
                "success" -> m("show.success"),
                "event" -> "confirmation-update"
              )
          }
        }
        case None => BadRequest(views.html.Confirmation.show())
      }
    }
  }
}
