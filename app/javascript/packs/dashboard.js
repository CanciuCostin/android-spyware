import { Application } from "@hotwired/stimulus"
import DashboardController from "../controllers/dashboard_controller"

const application = Application.start()
application.register("dashboard", DashboardController)
