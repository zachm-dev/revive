# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

jQuery ->
	$('#crawl_moz_da, #crawl_majestic_tf').ionRangeSlider(
		min: 0,
		max: 100
	);
	
	$('#crawl_notify_me_after').ionRangeSlider(
		min: 0,
		max: 50000
	);
