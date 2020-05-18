$(document).ready(function(){
$(function() {
	setInterval(function() {
		percent = Math.floor(Math.random() * 100);
		$("#gaugeCPU").attr("percent", percent);
		$("#gaugeCPU text.value tspan").text(percent + "%");
	}, 3000);

	setInterval(function() {
		percent = Math.floor(Math.random() * 100);
		$("#gaugeMemory").attr("percent", percent);
		$("#gaugeMemory text.value tspan").text(percent + "%");
	}, 5000);
	
	setInterval(function() {
		percent = Math.floor(Math.random() * 100);
		$("#gaugeStorage").attr("percent", percent);
		$("#gaugeStorage text.value tspan").text(percent + "%");
	}, 8000);
	
});

});