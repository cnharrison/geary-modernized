/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class Geary.ImapEngine.FlagSearchTest : TestCase {

    public FlagSearchTest() {
        base("Geary.ImapEngine.FlagSearchTest");
        add_test("unread_uses_unseen_criteria", unread_uses_unseen_criteria);
        add_test("starred_uses_flagged_criteria", starred_uses_flagged_criteria);
        add_test("retains_only_matching_uids", retains_only_matching_uids);
        add_test(
            "new_uid_requests_complete_fields",
            new_uid_requests_complete_fields
        );
        add_test(
            "completes_only_matching_vector_uids",
            completes_only_matching_vector_uids
        );
    }

    public void unread_uses_unseen_criteria() throws GLib.Error {
        Imap.SearchCriteria criteria = get_flag_search_criteria(
            FolderSupport.FlagFilter.UNREAD
        );

        assert_equal<string>(criteria.to_string(), "(unseen)");
    }

    public void starred_uses_flagged_criteria() throws GLib.Error {
        Imap.SearchCriteria criteria = get_flag_search_criteria(
            FolderSupport.FlagFilter.STARRED
        );

        assert_equal<string>(criteria.to_string(), "(flagged)");
    }

    public void new_uid_requests_complete_fields() throws GLib.Error {
        Email.Field requested = Email.Field.ENVELOPE | Email.Field.PREVIEW;

        Email.Field fields = get_server_search_new_email_fields(requested);

        assert(fields.fulfills(requested));
        assert(fields.fulfills(ImapDB.Folder.REQUIRED_FIELDS));
    }

    public void completes_only_matching_vector_uids() throws GLib.Error {
        var matching = new Gee.HashSet<Imap.UID>();
        matching.add(new Imap.UID(2));

        assert_false(
            should_complete_list_result(new Imap.UID(1), matching)
        );
        assert_true(
            should_complete_list_result(new Imap.UID(2), matching)
        );
        assert_true(should_complete_list_result(new Imap.UID(1), null));
    }

    public void retains_only_matching_uids() throws GLib.Error {
        var first = new Email(
            new ImapDB.EmailIdentifier(1, new Imap.UID(1))
        );
        var second = new Email(
            new ImapDB.EmailIdentifier(2, new Imap.UID(2))
        );
        var emails = new Gee.ArrayList<Email>();
        emails.add(first);
        emails.add(second);
        var matches = new Gee.HashSet<Imap.UID>();
        matches.add(new Imap.UID(2));

        retain_server_search_results(emails, matches);

        assert_equal<int?>(emails.size, 1, "Retained email count");
        assert(emails.contains(second));
    }

}
