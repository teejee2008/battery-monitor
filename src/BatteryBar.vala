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
		
		var color_blue_500 = Gdk.RGBA();
		color_blue_500.parse("#2196F3");
		color_blue_500.alpha = 1.0;

		bar.draw.connect ((context) => {
			int w = bar.get_allocated_width();
			int h = bar.get_allocated_height();
			
			Gdk.cairo_set_source_rgba (context, color_black);
			context.set_line_width (1);

			context.rectangle(0, 0, w, h);
			context.fill();

			Gdk.cairo_set_source_rgba (context, color_blue_200);
			context.set_line_width (1);

			context.rectangle(0, 1, w/2, h);
			context.fill();
			
			return true;
		});
	}
}

