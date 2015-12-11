/*
 * BatteryStatsWindow.vala
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

public class BatteryStatsWindow : Window {
	private Box vbox_main;
	private Box hbox_stats_line1;
	private Box hbox_stats_line2;
	private Box hbox_top_line1;
	private CheckButton chk_enable;

	private Gtk.DrawingArea drawing_area;

	private Label lbl_date_val;
	private Label lbl_charge_val;
	private Label lbl_voltage_val;
	private Label lbl_cpu_val;
	private Label lbl_discharge_val;
	private Label lbl_cycle_summary_val;
	private Label lbl_cycle_summary_life_val;
	private Label lbl_cycle_summary_remaining_val;
	private Gtk.Image img_battery_status;
	
	BatteryStat stat_current;
	int X_INTERVAL = 5;
	int X_OFFSET = 30;
	int Y_OFFSET = 20;

	uint timer_refresh = 0;

	int def_width = 500;
	int def_height = 500;

	private Gdk.RGBA color_white;
	private Gdk.RGBA color_black;
	private Gdk.RGBA color_red;
	private Gdk.RGBA color_blue;
	private Gdk.RGBA color_red_100;
		
	public BatteryStatsWindow() {
		destroy.connect(Gtk.main_quit);
		init_window();
	}

	public BatteryStatsWindow.with_parent(Window parent) {
		set_transient_for(parent);
		set_modal(true);
		init_window();
		init_window_for_parent();
	}

	public void init_window () {
		if (check_if_path_is_mounted_on_tmpfs("/var/spool")){
			string msg = _("/var/spool on your system is mounted in memory (tmpfs)!!\n\n/var/spool should never be mounted in tmpfs as the user's cron jobs are stored here along with other system files. If you have done this to reduce writes to your SSD, please undo it by editing your /etc/fstab file. This application will not work till this is corrected.");
			gtk_messagebox("System Issue",msg,this,true);
			exit(1);
		}

		define_colors();
		
		title = "Aptik Battery Monitor" + " v" + AppVersion;
		window_position = WindowPosition.CENTER;
		resizable = true;
		set_default_size (def_width, def_height);

		//vbox_main
		vbox_main = new Box (Orientation.VERTICAL, 6);
		vbox_main.margin = 6;
		add (vbox_main);

		init_header();

		init_graph();

		init_stats();

		//TODO: Should start if not already running

		show_all();

		timer_refresh_graph();
		
		timer_refresh = Timeout.add(30 * 1000, timer_refresh_graph);
	}

	public void define_colors(){
		color_white = Gdk.RGBA();
		color_white.parse("white");
		color_white.alpha = 1.0;

		color_black = Gdk.RGBA();
		color_black.parse("black");
		color_black.alpha = 1.0;

		color_red = Gdk.RGBA();
		color_red.parse("red");
		color_red.alpha = 1.0;

		color_blue = Gdk.RGBA();
		color_blue.parse("blue");
		color_blue.alpha = 1.0;
		
		color_red_100 = Gdk.RGBA();
		color_red_100.parse("#FFCDD2");
		color_red_100.alpha = 1.0;
	}
	
	public void init_window_for_parent() {
		//btn_actions.hide();
		//btn_selections.hide();
	}

	public void init_header() {
		hbox_top_line1 = new Box (Orientation.HORIZONTAL, 6);
		//hbox_stats_line1.margin = 6;
		vbox_main.add (hbox_top_line1);

		chk_enable = new CheckButton.with_label (_("Enable logging"));
		//chk_enable.margin_left = 6;
		hbox_top_line1.add(chk_enable);

		chk_enable.active = (App.is_logging_enabled());

		chk_enable.clicked.connect (() => {
			App.set_battery_monitoring_status_cron(chk_enable.active);
		});

		var lbl_spacer = new Label("");
		lbl_spacer.hexpand = true;
		hbox_top_line1.add(lbl_spacer);

		//btn_settings
		var btn_settings = new Gtk.Button.from_stock ("gtk-missing-image");
		btn_settings.label = _("Settings");
		//btn_settings.label = "";
		btn_settings.set_tooltip_text (_("Settings"));
		//btn_settings.image = get_shared_icon("gnome-settings","config.svg",16);
		//btn_settings.always_show_image = true;
		//btn_settings.image_position = PositionType.RIGHT;
		hbox_top_line1.add(btn_settings);

		btn_settings.clicked.connect(() => {
			var dialog = new SettingsWindow();
			dialog.set_transient_for(this);
			dialog.show_all();
			dialog.run();
			dialog.destroy();
		});
		
		//btn_donate
		var btn_donate = new Gtk.Button.from_stock ("gtk-missing-image");
		btn_donate.label = _("Donate");
		//btn_donate.label = "";
		btn_donate.set_tooltip_text (_("Donate"));
		//btn_donate.image = get_shared_icon("donate","donate.svg",16);
		//btn_donate.always_show_image = true;
		//btn_donate.image_position = PositionType.RIGHT;
		hbox_top_line1.add(btn_donate);

		btn_donate.clicked.connect(() => {
			var dialog = new DonationWindow();
			dialog.set_transient_for(this);
			dialog.show_all();
			dialog.run();
			dialog.destroy();
		});

		//btn_about
		var btn_about = new Gtk.Button.from_stock ("gtk-about");
		btn_about.label = _("Info");
		//btn_about.label = "";
		btn_about.set_tooltip_text (_("Application Info"));
		//btn_about.image = get_shared_icon("gtk-about","help-info.svg",16);
		//btn_about.always_show_image = true;
		//btn_about.image_position = PositionType.RIGHT;
		hbox_top_line1.add(btn_about);

		btn_about.clicked.connect (btn_about_clicked);
	}

	private void btn_about_clicked () {
		var dialog = new AboutWindow();
		dialog.set_transient_for (this);

		dialog.authors = {
			"Tony George:teejeetech@gmail.com"
		};

		dialog.translators = {
			//"giulux (Italian)",
			//"Jorge Jamhour (Brazilian Portuguese):https://launchpad.net/~jorge-jamhour",
			//"B. W. Knight (Korean):https://launchpad.net/~kbd0651",
			//"Rodion R. (Russian):https://launchpad.net/~r0di0n"
		};

		dialog.documenters = null;
		dialog.artists = null;
		dialog.donations = null;

		dialog.program_name = AppName;
		dialog.comments = _(" A Battery Monitoring Utility for Laptops");
		dialog.copyright = "Copyright © 2015 Tony George (%s)".printf(AppAuthorEmail);
		dialog.version = AppVersion;
		dialog.logo = get_app_icon(128);

		dialog.license = "This program is free for personal and commercial use and comes with absolutely no warranty. You use this program entirely at your own risk. The author will not be liable for any damages arising from the use of this program.";
		dialog.website = "http://teejeetech.in";
		dialog.website_label = "http://teejeetech.blogspot.in";

		dialog.initialize();
		dialog.show_all();
	}

	public void init_graph() {
		drawing_area = new Gtk.DrawingArea();
		drawing_area.set_size_request(400, 200);
		drawing_area.margin = 10;

		var sw_graph = new ScrolledWindow(null, null);
		sw_graph.set_shadow_type (ShadowType.ETCHED_IN);
		sw_graph.expand = true;

		sw_graph.add (drawing_area);
		vbox_main.add(sw_graph);

		App.read_battery_stats();
		
		drawing_area.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);

		drawing_area.button_press_event.connect((event) => {
			BatteryStat stat_prev = null;
			foreach(var stat in App.battery_stats_list) {
				if (stat.date == null) {
					continue;
				}

				if (Math.fabsf((float)(stat.graph_x - event.x)) < X_INTERVAL) {
					stat_current = stat;
					update_info_stats(stat,stat_prev);
				}
				
				stat_prev = stat;
			}
			redraw_graph_area();
			return true;
		});
			
		drawing_area.draw.connect ((context) => {
			//weak Gtk.StyleContext style_context = drawing_area.get_style_context ();
			//var color_default = style_context.get_color (0);
			
			var color_default = color_black;

			Gdk.cairo_set_source_rgba (context, color_default);
			context.set_line_width (1);

			int stat_count = (App.battery_stats_list.size > 2880) ? 2880 : App.battery_stats_list.size;

			//int w = drawing_area.get_allocated_width();
			int h = drawing_area.get_allocated_height();

			//int w_eff = w - X_OFFSET;
			int h_eff = h - 2 * Y_OFFSET;

			//double pxw = (w_eff / 100.00);
			double pxh = (h_eff / 100.00);

			long x0 = X_OFFSET;
			long y0 = h - Y_OFFSET;
			long x100 = x0 + (stat_count * X_INTERVAL);
			long y100 = Y_OFFSET;

			long x, x_prev, y, y_prev, y_cpu, y_prev_cpu;
			x = x_prev = x0;
			y = y_prev = y_cpu = y_prev_cpu = y0;

			int count = 0;
			BatteryStat stat_prev = null;
			int count_24_hours = 2880;

			int x_interval_counter = 0;
			foreach(var stat in App.battery_stats_list) {
				if (stat.date == null) {
					continue;
				}
				count++;

				if (App.battery_stats_list.size > count_24_hours) {
					if (count < (App.battery_stats_list.size - 2880)) {
						//ignore entries older than latest 2880 records
						continue;
					}
				}

				x += X_INTERVAL;
				stat.graph_x = x;

				if (stat_prev != null) {
					if (stat_prev.date.add_seconds(Main.BATT_STATS_LOG_INTERVAL + 1).compare(stat.date) < 0) {

						//draw double-vertical lines to indicate time gap
						
						//------ BEGIN CONTEXT -------------------------------------------
						context.set_line_width (0.5);
						Gdk.cairo_set_source_rgba (context, color_default);

						//draw a vertical line
						context.move_to(x_prev, y0);
						context.line_to(x_prev, y100);

						//draw a vertical line
						context.move_to(x, y0);
						context.line_to(x, y100);

						context.stroke ();
						//------ END CONTEXT -----------------------------------------
					}
					else {
						//------ BEGIN CONTEXT -------------------------------------------
						context.set_line_width (0.5);
						Gdk.cairo_set_source_rgba (context, color_default);

						for (int p = 10; p <= 100; p += 10) {
							long y_interval = (long) (h - Y_OFFSET - (p * pxh));
							//draw Y-axis lines
							context.move_to(x_prev, y_interval);
							context.line_to(x, y_interval);
						}

						context.stroke ();
						//------ END CONTEXT ---------------------------------------------

						//------ BEGIN CONTEXT -------------------------------------------
						context.set_line_width (1);
						Gdk.cairo_set_source_rgba (context, color_default);

						//draw battery line for stat ---------------------------

						context.move_to (x_prev, y_prev);

						y = (long) ((stat.charge_now * 100.00 * pxh) / BatteryStat.batt_charge_full());
						y = h - Y_OFFSET - y;

						context.line_to (x, y);

						context.stroke ();
						//------ END CONTEXT ---------------------------------------------

						//------ BEGIN CONTEXT -------------------------------------------
						context.set_line_width (1);
						Gdk.cairo_set_source_rgba (context, color_red);

						//draw cpu line for stat ----------------

						context.move_to (x_prev, y_prev_cpu);

						y_cpu = (long) (stat.cpu_percent() * pxh);
						y_cpu = h - Y_OFFSET - y_cpu;
						context.line_to (x, y_cpu);

						y_prev_cpu = y_cpu;

						context.stroke ();
						//------ END CONTEXT ---------------------------------------------
					}
				}

				if ((stat_current != null) && (stat_current.date == stat.date)) {
					//------ BEGIN CONTEXT -------------------------------------------
					context.set_line_width (0.5);
					Gdk.cairo_set_source_rgba (context, color_blue);
					//draw a vertical line for selected stat
					context.move_to(x, y0);
					context.line_to(x, y100);
					context.stroke ();
					//------ END CONTEXT ---------------------------------------------
				}

				//------ BEGIN CONTEXT -------------------------------------------------
				context.set_line_width (1);
				Gdk.cairo_set_source_rgba (context, color_default);

				//draw X-axis ticks and time label for stat -----------------

				x_interval_counter++;
				
				if (((stat.date.get_minute() % 10) == 0) && (stat.date.get_second() < 30)) {
					//draw X-axis tick
					context.move_to(x, y0 - 2);
					context.line_to(x, y0 + 2);
					
					if (x_interval_counter >= 20){
						//draw time on X-axis tick
						context.move_to (x - 15, h - Y_OFFSET + 20);
						context.show_text(stat.date.format("%I:%M %p"));
					}

					x_interval_counter = 0;
				}

				context.stroke ();
				//------ END CONTEXT ---------------------------------------------------
				
				stat_prev = stat;
				if (stat_current == null) {
					stat_current = stat;
				}
				x_prev = x;
				y_prev = y;
			}

			//------ BEGIN CONTEXT -------------------------------------------------

			context.set_line_width (1);
			Gdk.cairo_set_source_rgba (context, color_default);

			//draw axis lines -----------------------------

			//draw X-axis line
			context.move_to(x0,   y0);
			context.line_to(x100, y0);

			//draw Y-axis line
			context.move_to(x0, y0);
			context.line_to(x0, y100);

			context.stroke ();

			//------ END CONTEXT ---------------------------------------------------

			//------ BEGIN CONTEXT -------------------------------------------------
			context.set_line_width (0.5);

			//draw Y-axis markers and labels ------------------------

			for (int p = 10; p <= 100; p += 10) {
				y = (long) (h - Y_OFFSET - (p * pxh));

				//draw Y-axis markers
				context.move_to(x0 + 2, y);
				context.line_to(x0 - 2, y);

				/*
				//draw Y-axis lines
				context.move_to(x0,   y);
				context.line_to(x100, y);
				*/

				//draw Y-axis labels
				context.move_to (x0 - X_OFFSET, y);
				context.show_text("%d%%".printf(p));
			}

			context.stroke ();
			//------ END CONTEXT ---------------------------------------------------

			drawing_area.set_size_request((X_INTERVAL * stat_count) + (2 * X_OFFSET), -1);

			return true;
		});
	}

	public void init_stats() {
		Gtk.Frame frame_selected = new Gtk.Frame ("<b>Selected:</b>");
		(frame_selected.label_widget as Gtk.Label).use_markup = true;
		vbox_main.add (frame_selected);

		var hbox_stats_and_icon = new Box (Orientation.HORIZONTAL, 6);
		frame_selected.add (hbox_stats_and_icon);
		
		var vbox_stats_selected = new Box (Orientation.VERTICAL, 6);
		vbox_stats_selected.margin = 6;
		vbox_stats_selected.hexpand = true;
		hbox_stats_and_icon.add (vbox_stats_selected);

		img_battery_status = get_shared_icon("notification-battery-060", "notification-battery-060.png", 80);
		img_battery_status.margin_right = 5;
		hbox_stats_and_icon.add (img_battery_status);
		
		// date -------------------------------------------------
		
		var hbox_stats_date = new Box (Orientation.HORIZONTAL, 6);
		vbox_stats_selected.add (hbox_stats_date);

		var lbl_date = new Label("<b>" + ("Date") + ":</b>");
		lbl_date.set_use_markup(true);
		hbox_stats_date.add(lbl_date);

		lbl_date_val = new Label(_("25 Aug 2015, 10:35:16 PM"));
		hbox_stats_date.add(lbl_date_val);

		// line1 ------------------------------------------------
		
		hbox_stats_line1 = new Box (Orientation.HORIZONTAL, 6);
		vbox_stats_selected.add (hbox_stats_line1);

		var lbl_charge = new Label("<b>" + ("Charge") + ":</b>");
		lbl_charge.set_use_markup(true);
		hbox_stats_line1.add(lbl_charge);

		lbl_charge_val = new Label(_("17.58%, 6200 mAh, 57.14 Wh"));
		hbox_stats_line1.add(lbl_charge_val);

		var lbl_voltage = new Label("<b>" + ("Voltage") + ":</b>");
		lbl_voltage.set_use_markup(true);
		hbox_stats_line1.add(lbl_voltage);

		lbl_voltage_val = new Label(_("8700 mV"));
		hbox_stats_line1.add(lbl_voltage_val);

		// line2 ------------------------------------------------
		
		hbox_stats_line2 = new Box (Orientation.HORIZONTAL, 6);
		vbox_stats_selected.add (hbox_stats_line2);

		var lbl_discharge = new Label("<b>" + ("Usage") + ":</b>");
		lbl_discharge.set_use_markup(true);
		hbox_stats_line2.add(lbl_discharge);

		lbl_discharge_val = new Label(_("17.58 % per hr, 8:10 hrs"));
		hbox_stats_line2.add(lbl_discharge_val);

		var lbl_cpu = new Label("<b>" + ("CPU") + ":</b>");
		lbl_cpu.set_use_markup(true);
		hbox_stats_line2.add(lbl_cpu);

		lbl_cpu_val = new Label(_("2%"));
		hbox_stats_line2.add(lbl_cpu_val);

		//TODO: Show values in color
		//TODO: Show legends

		//show empty values
		lbl_date_val.label = (new DateTime.now_local()).format("%d %b %Y, %I:%M %p"); //%F %H:%M:%S
		lbl_charge_val.label = "%0.2f%%, %0.0f mAh, %0.2f Wh".printf(0.0, 0.0, 0.0);
		lbl_voltage_val.label = "%0.2f V".printf(0.0);
		lbl_cpu_val.label = "%0.2f %%".printf(0.0);
		lbl_discharge_val.label = "00.00%/hr, 0.0 hrs";

		// line3 ------------------------------------------------
				
		Gtk.Frame frame_averages = new Gtk.Frame ("<b>Averages:</b>");
		(frame_averages.label_widget as Gtk.Label).use_markup = true;
		vbox_main.add (frame_averages);

		var vbox_stats_avg = new Box (Orientation.VERTICAL, 6);
		vbox_stats_avg.margin = 6;
		frame_averages.add (vbox_stats_avg);
		
		var hbox_stats_line3 = new Box (Orientation.HORIZONTAL, 6);
		vbox_stats_avg.add (hbox_stats_line3);

		var lbl_cycle_summary = new Label("<b>" + ("Used") + ":</b>");
		lbl_cycle_summary.set_use_markup(true);
		hbox_stats_line3.add(lbl_cycle_summary);

		lbl_cycle_summary_val = new Label(_("Used 00.00 % in 0h 0m @ 0.0 % per hour"));
		hbox_stats_line3.add(lbl_cycle_summary_val);

		// line4 --------------------------------------------
		
		var hbox_stats_line4 = new Box (Orientation.HORIZONTAL, 6);
		//hbox_stats_line4.margin = 6;
		vbox_stats_avg.add (hbox_stats_line4);
		
		var lbl_cycle_summary_life = new Label("<b>" + ("Battery Life") + ":</b>");
		lbl_cycle_summary_life.set_use_markup(true);
		hbox_stats_line4.add(lbl_cycle_summary_life);

		lbl_cycle_summary_life_val = new Label(_("0h 0m"));
		hbox_stats_line4.add(lbl_cycle_summary_life_val);

		var lbl_cycle_summary_remaining = new Label("<b>" + ("Remaining") + ":</b>");
		lbl_cycle_summary_remaining.set_use_markup(true);
		hbox_stats_line4.add(lbl_cycle_summary_remaining);

		lbl_cycle_summary_remaining_val = new Label(_("0h 0m"));
		hbox_stats_line4.add(lbl_cycle_summary_remaining_val);
	}

	public bool timer_refresh_graph() {
		//if (timer_pkg_info > 0){
		//	Source.remove(timer_pkg_info);
		//	timer_pkg_info = 0;
		//}

		if (chk_enable.active) {
			App.read_battery_stats();
			select_latest_stat();
			update_info_current_cycle();
			update_battery_status_icon();
		}

		return true;
	}
	private void select_latest_stat(){
		var stat0 = App.battery_stats_list[App.battery_stats_list.size - 1];
		var stat1 = App.battery_stats_list[App.battery_stats_list.size - 2];
		stat_current = stat0;
		redraw_graph_area();
		update_info_stats(stat0,stat1);
	}
	
	private void redraw_graph_area() {
		drawing_area.queue_draw_area(0, 0,
		                             drawing_area.get_allocated_width(),
		                             drawing_area.get_allocated_height());
	}
			
	private void update_info_stats(BatteryStat stat, BatteryStat stat_prev){
		lbl_date_val.label = stat.date.format("%d %b %Y, %I:%M %p"); //%F %H:%M:%S
		//lbl_charge_val.label = "%ld, %ld".printf(stat.charge_now, BatteryStat.batt_charge_full());
		lbl_charge_val.label = "%0.2f %%, %0.0f mAh, %0.2f Wh".printf(
								   stat.charge_percent(),
								   stat.charge_in_mah(),
								   stat.charge_in_wh()
							   );
		lbl_voltage_val.label = "%0.2f V".printf(stat.voltage());
		lbl_cpu_val.label = "%0.2f %%".printf(stat.cpu_percent());
		if (stat_prev != null) {
			double rate = (stat_prev.charge_percent() - stat.charge_percent()) * 2 * 60;
			double estimated = 100 / rate;
			lbl_discharge_val.label = "%0.2f %% per hr, %0.1f hrs".printf(rate, estimated);
		}
	}
	
	private void update_info_current_cycle(){
		var cycle = new BatteryCycle();
		cycle.calculate_stats(App.battery_stats_list);
			
		var stat_first = App.battery_stats_list[0];
		var stat_current = App.battery_stats_list[App.battery_stats_list.size - 1];
		var drop = stat_first.charge_percent() - stat_current.charge_percent();
		int mins = (int)(App.battery_stats_list.size * 0.5);
		
		lbl_cycle_summary_val.label = cycle.used_string();
		lbl_cycle_summary_life_val.label = cycle.battery_life_string();
		lbl_cycle_summary_remaining_val.label = cycle.remaining_time_string();
	}

	private void update_battery_status_icon(){
		var icon_name = "notification-battery";

		var stat = new BatteryStat.read_from_sys();
		double percent = stat.charge_percent();

		if (percent == 100){
			icon_name += "-100";
		}
		else if (percent >= 80){
			icon_name += "-080";
		}
		else if (percent >= 60){
			icon_name += "-060";
		}
		else if (percent >= 40){
			icon_name += "-040";
		}
		else if (percent >= 20){
			icon_name += "-020";
		}
		else if (percent >= 0){
			icon_name += "-000";
		}
		
		if (BatteryStat.is_charging()){
			icon_name += "-plugged";
		}

		var img = get_shared_icon(icon_name, "%s.png".printf(icon_name), 48);
		if (img != null){
			img_battery_status.set_from_pixbuf(img.pixbuf);
		}
	}
}

