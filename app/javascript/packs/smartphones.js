require("@rails/ujs").start()
require("@rails/activestorage").start()
require("channels")


import "bootstrap"
import "../stylesheets/application" 





$(document).ready( () => {
    $('[data-toggle="tooltip"]').tooltip()
    $('[data-toggle="popover"]').popover()
    $('[data-toggle="carousel"]').carousel()
    $('[data-toggle="dropdown"]').dropdown()

})