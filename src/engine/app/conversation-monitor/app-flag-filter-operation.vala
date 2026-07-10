/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** Loads every message matching a monitor's server-side flag filter. */
private class Geary.App.FlagFilterOperation : ConversationOperation {

    public FlagFilterOperation(ConversationMonitor monitor) {
        base(monitor);
    }

    public override async void execute_async() throws GLib.Error {
        yield this.monitor.load_flag_filter_async();
    }

}
