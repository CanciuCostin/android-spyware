// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//= require particles.js
//= require_tree .
//= require turbolinks
require("@rails/ujs").start();
require("@rails/activestorage").start();
require("channels");
require("turbolinks").start();

import "../stylesheets/application";

$(document).on("turbolinks:load", function () {
  alert("turbolinks on load event works");
});

document.addEventListener("turbolinks:load", () => {
  console.log("load");
  alert("turbolinks on load event works");
  $('[data-toggle="tooltip"]').tooltip();
  $('[data-toggle="popover"]').popover();
  $('[data-toggle="carousel"]').carousel();
  $('[data-toggle="dropdown"]').dropdown();
});

// Uncomment to copy all static images under ../images to the output folder and reference
// them with the image_pack_tag helper in views (e.g <%= image_pack_tag 'rails.png' %>)
// or the `imagePath` JavaScript helper below.
//
// const images = require.context('../images', true)
// const imagePath = (name) => images(name, true)
