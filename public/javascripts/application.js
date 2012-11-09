!function ($) {
	$(function(){
		// 日期多选
		var start_at = $('input[name="start_at"]');
		var end_at   = $('input[name="end_at"]');
		$('.calendar').DatePicker({
			date: [ start_at.val(), end_at.val() ],
			current: end_at.val(),
			calendars: 2,
			starts: 1,
			onChange: function(formated, dates){
				start_at.val(formated[0]);
				end_at.val(formated[1]);
			}
		});
		// 多选框
		$('.chzn-select').chosen();
		$(".chzn-select-deselect").chosen({allow_single_deselect:true});
		// 下拉菜单
		$('.dropdown-toggle').dropdown();
		 // tooltip
		 $('[rel=popover]').popover({placement: 'bottom'});
		 $('[rel=tooltip]').tooltip({});
		 // radio伪装toggle按钮
		 $('label.btn.active').each(function() {
		    var label = $(this), inputId = label.attr('for'), btn_group = label.parent();
		    btn_group.children('.active').removeClass('active'); // 去除页面固定值的样式
				$('#' + inputId).prop('checked', true);
		 });
		 // 防止ajax重复请求
		 $("a[data-remote=true]").live('click', function(e) {
			  var el = $(this);
			  el.tooltip('destroy'); // 修复tooltip
			  el.replaceWith('<img src=/img/spinner.gif />');
			});

		 // 浮动菜单效果
	    var $win = $(window)
	      , $nav = $('.subnav')
	      , navTop = $('.subnav').length && $('.subnav').offset().top - 40
	      , isFixed = 0

	    processScroll()

	    $win.on('scroll', processScroll)

	    function processScroll() {
	      var i, scrollTop = $win.scrollTop()
	      if (scrollTop >= navTop && !isFixed) {
	        isFixed = 1
	        $nav.addClass('subnav-fixed')
	      } else if (scrollTop <= navTop && isFixed) {
	        isFixed = 0
	        $nav.removeClass('subnav-fixed')
	      }
	    }

	  /*
	   *     特定页面效果
	   */

	  // 客服交易
		$('#trades.nav-tabs a').click(function (e) {
		  e.preventDefault();
		  $(this).tab('show');
		})
		// 客服交易
		$('#subusers td.payment').graphup({
			min: 0,
			cleaner: 'strip',
			painter: 'bars',
			colorMap: [[145,89,117], [102,0,51]]
		});
	})
}(window.jQuery)