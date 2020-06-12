$(document).ready(function(){
$(function() {
	
	setInterval(function() {
		percent = Math.floor(Math.random() * 100);
		$("#gaugeStorage").attr("percent", percent);
		$("#gaugeStorage text.value tspan").text(percent + "%");
	}, 8000);
	
});

});