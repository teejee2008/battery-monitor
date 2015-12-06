/*
 * BatteryBar.vala
 *
 * Copyright 2015 Tony George <teejee2008@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */


using Gtk;
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

public class BatteryBar : Window {

	private Gtk.DrawingArea bar;
	uint timer_refresh = 0;
	
	public static int main (string[] args) {
		set_locale();

		Gtk.init(ref args);

		init_tmp();

		App = new Main(args, true);

		var bar = new BatteryBar();
		bar.destroy.connect(Gtk.main_quit);
		bar.show_all();

		//start event loop
		Gtk.main();

		return 0;
	}

	private static void set_locale() {
		Intl.setlocale(GLib.LocaleCategory.MESSAGES, AppShortName);
		Intl.textdomain(GETTEXT_PACKAGE);
		Intl.bind_textdomain_codeset(GETTEXT_PACKAGE, "utf-8");
		Intl.bindtextdomain(GETTEXT_PACKAGE, LOCALE_DIR);
	}

	public BatteryBar() {
		int bar_height = 6;
		int screen_width = Gdk.Screen.width();
		int screen_height = Gdk.Screen.height();

		set_size_request(screen_width, bar_height);
		set_decorated(false);
		set_keep_above(true);
		set_skip_taskbar_hint(true);
		set_skip_taskbar_hint(true);

		move(0, screen_height - bar_height);

		this.button_press_event.connect((event) => {
			this.close();
			return true;
		});

		bar = new Gtk.DrawingArea();
		bar.expand = true;
		add(bar);

		var color_white = Gdk.RGBA();
		color_white.parse("white");
		color_white.alpha = 1.0;

		var color_black = Gdk.RGBA();
		color_black.parse("black");
		color_black.alpha = 1.0;

		var color_red = Gdk.RGBA();
		color_red.parse("red");
		color_red.alpha = 1.0;

		var color_blue_200 = Gdk.RGBA();
		color_blue_200.parse("#90CAF9");
		color_blue_200.alpha = 1.0;
		
		var color_green_300 = Gdk.RGBA();
		color_green_300.parse("#81C784");
		color_green_300.alpha = 1.0;

		var color_yellow_300 = Gdk.RGBA();
		color_yellow_300.parse("#FFF176");
		color_yellow_300.alpha = 1.0;
		
		var color_red_300 = Gdk.RGBA();
		color_red_300.parse("#E57373");
		color_red_300.alpha = 1.0;
		
		Gdk.RGBA color_bar = color_green_300;
		
		bar.draw.connect ((context) => {
			int w = bar.get_allocated_width();
			int h = bar.get_allocated_height();

			double charge_level = BatteryStat.batt_charge_percent();
			int x_level = (int) ((w * charge_level) / 100.00);
			bar.set_tooltip_markup("<span size='xx-large'>Battery: %.2f %%</span>".printf(charge_level));
			
			if (charge_level >= 60){
				color_bar = color_green_300;
			}
			else if (charge_level >= 20){
				color_bar = color_yellow_300;
			}
			else{
				color_bar = color_red_300;
			}
			
			Gdk.cairo_set_source_rgba (context, color_black);
			context.set_line_width (1);

			context.rectangle(0, 0, w, h);
			context.fill();

			Gdk.cairo_set_source_rgba (context, color_bar);
			context.set_line_width (1);

			context.rectangle(0, 1, x_level, h);
			context.fill();
			
			return true;
		});

		timer_refresh = Timeout.add(30 * 1000, timer_refresh_bar);
	}

	public bool timer_refresh_bar() {
		//if (timer_pkg_info > 0){
		//	Source.remove(timer_pkg_info);
		//	timer_pkg_info = 0;
		//}
		redraw_bar();
		
		return true;
	}
	
	private void redraw_bar() {
		bar.queue_draw_area(0, 0, bar.get_allocated_width(),
		                          bar.get_allocated_height());
	}
}

