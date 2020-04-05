//= require active_admin/base
//= require_tree .
$(document).ready(function(){
    $(".alerttt" ).fadeOut(3000);
    $("#carouselContainer").hide();

    //document.getElementById("dashboardContainer").style.opacity = "0.1";


    $(".load").on('click', function(event){
        $(".alerttt" ).fadeIn(3000);
        $(".alerttt" ).fadeOut(3000);
    
        //(... rest of your JS code)
    });

    $("#customSwitch1").change(function() {
        if(this.checked){
            $("#dashboardContainer").hide()
            $("#carouselContainer").fadeIn(1000);
        }
        else{
            $("#carouselContainer").hide()
            $("#dashboardContainer").fadeIn(1000);
        }
    });



   

});







