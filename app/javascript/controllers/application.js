import { Application } from '@hotwired/stimulus'
import * as Sentry from "@sentry/browser";

const application = Application.start()

function getMetaContent(name) {
  const meta = document.querySelector(`meta[name="${name}"]`);
  return meta ? meta.content : null;
}

// Configure Stimulus development experience
application.debug = getMetaContent("environment") === "development";
window.Stimulus = application

if (getMetaContent("environment") !== "development") {
  Stimulus.handleError = (error, message, detail) => {
    console.error(message, detail)
    Sentry.init({dsn: getMetaContent("sentryDSNUrl"),});
    Sentry.captureException(error);
  }
}

export { application }
