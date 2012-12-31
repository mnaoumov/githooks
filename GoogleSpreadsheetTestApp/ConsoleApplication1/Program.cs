using System;
using Google.GData.Spreadsheets;

namespace ConsoleApplication1
{
    class Program
    {
        static SpreadsheetsService _service;
        static ListQuery _listQuery;
        static ListQuery _filteredQuery;
        const string UserName = "git.helper@gmail.com";
        const string Password = "git.helper123";
        const string SpreadsheetTitle = "Git Force Push";

        static void Main(string[] args)
        {
            var userName = "Michael Naumov";

            EnableForcePush(userName, "No reason");

            Console.WriteLine(TestForcePushAllowed(userName));

            DisableForcePush(userName);

            Console.WriteLine(TestForcePushAllowed(userName));

            Console.ReadLine();
        }

        static void EnableForcePush(string userName, string reason)
        {
            Init(userName);

            var listFeed = _service.Query(_listQuery);

            var listEntry = new ListEntry
                                {
                                    Elements =
                                        {
                                            new ListEntry.Custom
                                                {
                                                    LocalName = "timestamp", Value = DateTime.UtcNow.ToString()
                                                },
                                            new ListEntry.Custom
                                                {
                                                    LocalName = "username", Value = userName,
                                                },
                                            new ListEntry.Custom
                                                {
                                                    LocalName = "reason", Value = reason,
                                                },
                                            new ListEntry.Custom
                                                {
                                                    LocalName = "enabled", Value = "Yes",
                                                },
                                        }
                                };

            _service.Insert(listFeed, listEntry);
        }

        static void Init(string userName)
        {
            _service = new SpreadsheetsService("MySpreadsheetIntegration-v1");
            _service.setUserCredentials(UserName, Password);

            var spreadsheetQuery = new SpreadsheetQuery { Title = SpreadsheetTitle };
            var spreadsheetFeed = _service.Query(spreadsheetQuery);
            var spreadsheet = (SpreadsheetEntry) spreadsheetFeed.Entries[0];

            var wsFeed = spreadsheet.Worksheets;
            var worksheet = (WorksheetEntry) wsFeed.Entries[0];

            var listFeedLink = worksheet.Links.FindService(GDataSpreadsheetsNameTable.ListRel, null);

            _listQuery = new ListQuery(listFeedLink.HRef.ToString());
            _filteredQuery = new ListQuery(listFeedLink.HRef.ToString()) { SpreadsheetQuery = string.Format("enabled=Yes and username=\"{0}\"", userName) };
        }

        static bool TestForcePushAllowed(string userName)
        {
            Init(userName);

            var listFeed = _service.Query(_filteredQuery);
            return listFeed.Entries.Count != 0;
        }

        static void DisableForcePush(string userName)
        {
            Init(userName);

            var listFeed = _service.Query(_filteredQuery);
            var row = (ListEntry) listFeed.Entries[0];

            foreach (ListEntry.Custom element in row.Elements)
            {
                if (element.LocalName == "enabled")
                    element.Value = "No";
            }

            row.Update();
        }
    }
}