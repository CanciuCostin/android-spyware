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

    $( ".Terminal__body" ).on( "write", function(event, ps1, input, output) {
        $(".Terminal__body").append("<span class=\"ps1\">" + ps1 + "</span>");
        $(".Terminal__body").append("<span class=\"input\">" + input + "</span>");
        $('.input').last().typeIt().stop();
        sleep(1000);
        $( ".Terminal__body")[0].scrollBy(0,180);
        var index;
        for (index = 0; index < output.length; ++index) {
            $(".Terminal__body").append("<div class=\"output\"><span>" + output[index] + "</span></div>");
    }
    });

    //$( ".bash" ).trigger("write",["msf >", "exploit", ["output1","output2"] ]);



    

})