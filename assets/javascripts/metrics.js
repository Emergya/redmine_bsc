DEFAULT_TABLE_HEIGHT = 380;
TIME_EXPAND_TABLE = 500;
TIME_CHANGE_CALENDAR = 500;
CALENDAR_DAYS_WARNING = 7;

$(document).ready(function(){
	// Show more/less table rows
	$(document).on('click', '.show_hide_rows', function(){
		if ($(this).data('table')){
			table = $("table#"+$(this).data('table'));
			panel = $("table#"+$(this).data('table')).parent();

			if ($(this).hasClass('show_more')){
				panel.animate({'max-height': table.height()}, TIME_EXPAND_TABLE, function(){ });
				$(this).removeClass('show_more');
				$('.gradiant_layer', $(this).parent().parent()).hide();
			} else {
				panel.animate({'max-height': DEFAULT_TABLE_HEIGHT+'px'}, TIME_EXPAND_TABLE, function(){ });
				$(this).addClass('show_more');
				$('.gradiant_layer', $(this).parent().parent()).show();
			}
		}
	});

	// Hide/show expandible option button on small tables at first load, after change metric tab and after resize browser
	hide_table_expandible_button(DEFAULT_TABLE_HEIGHT);
	$(document).ajaxComplete(function() {
		hide_table_expandible_button(DEFAULT_TABLE_HEIGHT);
	});
	$(window).on('resize', function(){
		hide_table_expandible_button(DEFAULT_TABLE_HEIGHT);
	});

	// Highligh row when hover chart points
	$(document).on({
	    mouseenter: function () {
		   	highlight_row(this);
	    },
	}, 'tr.table_row');


	// Change calendar to prev month
	$(document).on('click', '.calendar_prev', function(e){
		$('#calendar0').css('display','inline-block');
		$('#calendar4').css('display','inline-block');
		$('#calendar_container').animate(
			{
				'left': '+='+$('#calendar1').width()*1.03
			},
			TIME_CHANGE_CALENDAR, 
			function(){
				$('#calendar0').fullCalendar('prev');
				$('#calendar1').fullCalendar('prev');
				$('#calendar2').fullCalendar('prev');
				$('#calendar3').fullCalendar('prev');
				$('#calendar4').fullCalendar('prev');
				$('#calendar_container').css('left',0);
				$('#calendar0').hide();
				$('#calendar4').hide();
				calendar_tooltips();
			}
		);
	});


	// Change calendar to next month
	$(document).on('click', '.calendar_next', function(e){
		$('#calendar0').css('display','inline-block');
		$('#calendar4').css('display','inline-block');
		$('#calendar_container').animate(
			{
				'left': '-='+$('#calendar3').width()*1.03
			},
			TIME_CHANGE_CALENDAR, 
			function(){
				$('#calendar0').fullCalendar('next');
				$('#calendar1').fullCalendar('next');
				$('#calendar2').fullCalendar('next');
				$('#calendar3').fullCalendar('next');
				$('#calendar4').fullCalendar('next');
				$('#calendar_container').css('left',0);
				$('#calendar0').hide();
				$('#calendar4').hide();
				calendar_tooltips();
			}
		);
	});

	// Change currency
	$(document).on('change', '#currency_select', function(e){
		location.href = location.protocol + '//' + location.host + location.pathname + '?currency=' + $(this).val();
	});

	// Change date selector
	$(document).on('change', '#date_selector', function(e){
		change_metric(metric_selected, currency_id, $(this).val());
	});
});

// Change highlight table row
function highlight_row(row){
	$('tr.active').removeClass('active');
	$(row).addClass('active');
}

// Hide/show expandible button on shorter tables
function hide_table_expandible_button(panel_size){
	$('.panel-table.expandible').each(function(){
		if (panel_size >= $('table', this).height()){
			$('.show_hide_rows', $(this).parent()).hide();
			$('.gradiant_layer', $(this).parent()).hide();
		} else {
			$('.show_hide_rows', $(this).parent()).show();
			$('.gradiant_layer', $(this).parent()).show();
		}
	});
}

// Show tooltip message on rows with alert
function show_alert_row_tooltip(){
	
}




// load calendars options
function load_calendars(calendar_events){
	event_list = {};

	// Options for calendars
    calendar_options = {
        contentHeight: 400,
        header: {
            left: '',
            center: 'title',
            right: ''
        },
	    defaultDate: moment(),
	    theme: true,
	    eventSources: calendar_events,
	    eventRender: function(event, element, view) {
            // Set html content
            element.html($(event.content));
            // Set tooltip message in title
            element.attr('title', event.tooltip);
            // Hide other months events
            if (event.start.month() != view.intervalStart.month()) return false;

            // Highlight days with any event
		    days = $(".fc-day-top[data-date='"+event.start._i+"'], .fc-day[data-date='"+event.start._i+"'");
		    if ($(days).length > 0){
		        $(days).addClass('ui-state-highlight');
		    }
        },
        eventAfterAllRender: function(view){
        	// Add fc-near class
        	today = new Date();
        	for (i = 0; i<CALENDAR_DAYS_WARNING; i++){
        		today.setDate(today.getDate()+1);
        		date = today.toISOString().slice(0,10);
        		days = $(".fc-day-top[data-date='"+date+"'], .fc-day[data-date='"+date+"'");
        		if ($(days).length > 0){
			        $(days).addClass('fc-near');
			    }
        	}
        }
    }

    // Load calendars
    $('#calendar1').fullCalendar(calendar_options);

    calendar_options['defaultDate'] = moment().add(1, 'months');
    $('#calendar2').fullCalendar(calendar_options);

    calendar_options['defaultDate'] = moment().add(2, 'months');
    $('#calendar3').fullCalendar(calendar_options);

    calendar_options['defaultDate'] = moment().add(-1, 'months');
    $('#calendar0').fullCalendar(calendar_options).hide();

    calendar_options['defaultDate'] = moment().add(3, 'months');
    $('#calendar4').fullCalendar(calendar_options).hide();
}

// JqueryUI tooltip behaviour modification to show html content
function calendar_tooltips(){
    $("a.fc-day-grid-event.fc-h-event.fc-event").tooltip({
    	content: function () {
        	return $(this).prop('title');
    	}
    });
}

// Change metric tab
function change_metric(metric_option, currency, date_option){
	if (currency != 0){
		data = {type: metric_option, currency: currency, selected_date: date_option};
	}else{
		data = {type: metric_option, selected_date: date_option};
	}
	$.ajax({
		url: 'change_metric',
		data: data,
		success: function(data){
			$('#metric_contents').html(data['filter']);

			$('.metric_option').removeClass('active');
			$('#'+metric_option+'_header').addClass('active');
		}
	})
}



// Number formats
function currency(number, currency_json){
	currency_obj = $.parseJSON(currency_json);
	if ($.isEmptyObject(currency_obj)){
		return parseFloat(number).toLocaleString('es-ES', {style: 'currency', currency: 'EUR', minimumFractionsDigits: 2, maximumFractionsDigits: 2})
	}else{
		return FormatMoney(number * currency_obj['exchange'], '', currency_obj['symbol'], currency_obj['decimal_separator'], currency_obj['thousands_separator'], 2, 2);
	}
}

function hours(number){
	return parseFloat(number).toLocaleString('es-ES', {style: 'decimal',minimumFractionsDigits: 2, maximumFractionsDigits: 2})+"h"
}

function percent(number){
	return parseFloat(number).toLocaleString('es-ES', {style: 'decimal', maximumFractionsDigits: 2})+" %"
}