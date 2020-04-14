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


    var modal = document.getElementById("myModal");
    var btn = document.getElementById("phoneBtna");
    var span = document.getElementsByClassName("close")[0];
    btn.onclick = function() {
    modal.style.display = "block";
    }

    span.onclick = function() {
    modal.style.display = "none";
    }

    window.onclick = function(event) {
    if (event.target == modal) {
        modal.style.display = "none";
    }
    }

    $( ".bash" ).on( "write", function(event, jsonObj) {
        $(this).append("<span class=\"ps1\">" + jsonObj["PS1"] + "</span>");
        $(this).append("<span class=\"input\">" + jsonObj["input"] + "</span>");
        var index;
        for (index = 0; index < jsonObj["output"].length; ++index) {
            $(this).append("<div class=\"output\"><span>" + jsonObj["output"][index] + "</span></div>");
    }
        $('.input').last().typeIt().stop();
        $( ".bash")[0].scrollBy(0,180);
    });
    
    //controllers
    $("button.close").click(function(){
        $(".window").hide();
        $(".afterclose").fadeIn("fast");
    });
    
    $("button.open").click(function(){
        $(".window").show();
        $(".afterclose").hide();
    });
    
    $("button.maximize").click(function(){  $(".window").addClass("windowmax");  
        $(".bash").addClass("bashmax");
        $(".windowmax").removeClass("window");          
        $(".bashmax").removeClass("bash");
    });
    
    $("button.minimize").click(function(){
        $(".bash").remove();
        $(".window").addClass("windowmin");
        $(".windowmin").removeClass("window");
    });
    

})