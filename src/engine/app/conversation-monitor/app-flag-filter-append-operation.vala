/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** Loads newly available messages only when they match a flag filter. */
private class Geary.App.FlagFilterAppendOperation :
    BatchOperation<EmailIdentifier> {

    public FlagFilterAppendOperation(
        ConversationMonitor monitor,
        Gee.Collection<EmailIdentifier> ids
    ) {
        base(monitor, ids);
    }

    public override async void execute_batch(
        Gee.Collection<EmailIdentifier> batch
    ) throws GLib.Error {
        yield this.monitor.load_flag_filter_ids_async(batch);
    }

}
