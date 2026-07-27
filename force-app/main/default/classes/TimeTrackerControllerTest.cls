@IsTest
private class TimeTrackerControllerTest {

    /*
     * ----------------------------------------------------------
     * Success Mock
     * ----------------------------------------------------------
     */
    private class JiraSuccessMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            res.setBody(
            '{' +
            '"issues":[' +
                '{' +
                    '"key":"PUL-1",' +
                    '"fields":{' +
                        '"summary":"Development",' +
                        '"worklog":{' +
                            '"worklogs":[' +

                                '{' +
                                    '"started":"2026-07-20T10:00:00.000+0000",' +
                                    '"timeSpentSeconds":7200,' +
                                    '"author":{"displayName":"John"}' +
                                '},' +

                                '{' +
                                    '"started":"2026-07-21T10:00:00.000+0000",' +
                                    '"timeSpentSeconds":3600,' +
                                    '"author":{"displayName":"John"}' +
                                '},' +

                                /* Outside requested range.
                                   Should be ignored. */
                                '{' +
                                    '"started":"2026-07-30T10:00:00.000+0000",' +
                                    '"timeSpentSeconds":7200,' +
                                    '"author":{"displayName":"John"}' +
                                '}' +

                            ']' +
                        '}' +
                    '}' +
                '},' +

                '{' +
                    '"key":"PUL-2",' +
                    '"fields":{' +
                        '"summary":"Testing",' +
                        '"worklog":{' +
                            '"worklogs":[' +
                                '{' +
                                    '"started":"2026-07-21T11:00:00.000+0000",' +
                                    '"timeSpentSeconds":10800,' +
                                    '"author":{"displayName":"Alice"}' +
                                '}' +
                            ']' +
                        '}' +
                    '}' +
                '}' +

            ']}'
            );

            return res;
        }
    }

    /*
     * ----------------------------------------------------------
     * Empty Response
     * ----------------------------------------------------------
     */
    private class EmptyMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"issues":[]}');
            return res;

        }

    }

    /*
     * ----------------------------------------------------------
     * Error Response
     * ----------------------------------------------------------
     */
    private class ErrorMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Error');
            return res;

        }

    }

    /*
     * ----------------------------------------------------------
     * Success Test
     * ----------------------------------------------------------
     */
    @IsTest
    static void testSuccess() {

        Test.setMock(
            HttpCalloutMock.class,
            new JiraSuccessMock()
        );

        Test.startTest();

        TimeTrackerResponse response =
            TimeTrackerController.getTimeTrackerData(
                Date.newInstance(2026,7,20),
                Date.newInstance(2026,7,21),
                'PUL'
            );

        Test.stopTest();

        System.assertEquals(
            2,
            response.headers.size()
        );

        System.assertEquals(
            2,
            response.resources.size()
        );

        // Alice (3h) + John (3h)
        System.assertEquals(
            6,
            response.grandTotal
        );

        // Sorted alphabetically
        System.assertEquals(
            'Alice',
            response.resources[0].resourceName
        );

        System.assertEquals(
            'John',
            response.resources[1].resourceName
        );

        // John's total = 2h +1h
        System.assertEquals(
            3,
            response.resources[1].totalHours
        );

        // Outside-range worklog ignored
        System.assertEquals(
            2,
            response.resources[1]
                .hoursByDate.get('2026-07-20')
        );

        System.assertEquals(
            1,
            response.resources[1]
                .hoursByDate.get('2026-07-21')
        );

        // Issue summary stored
        System.assertEquals(
            'Development',
            response.resources[1]
                .issueSummaryMap.get('PUL-1')
        );

    }

    /*
     * ----------------------------------------------------------
     * Empty Issues
     * ----------------------------------------------------------
     */
    @IsTest
    static void testEmptyResponse() {

        Test.setMock(
            HttpCalloutMock.class,
            new EmptyMock()
        );

        Test.startTest();

        TimeTrackerResponse response =
            TimeTrackerController.getTimeTrackerData(
                Date.newInstance(2026,7,20),
                Date.newInstance(2026,7,21),
                null
            );

        Test.stopTest();

        System.assertEquals(
            0,
            response.resources.size()
        );

        System.assertEquals(
            2,
            response.headers.size()
        );

        System.assertEquals(
            0,
            response.grandTotal
        );

    }

    /*
     * ----------------------------------------------------------
     * HTTP Error
     * ----------------------------------------------------------
     */
    @IsTest
    static void testHttpError() {

        Test.setMock(
            HttpCalloutMock.class,
            new ErrorMock()
        );

        Test.startTest();

        Boolean exceptionThrown = false;

        try {

            TimeTrackerController.getTimeTrackerData(
                Date.today(),
                Date.today(),
                null
            );

        } catch (Exception ex) {

            exceptionThrown = true;

            // AuraHandledException is surfaced as "Script-thrown exception"
            // in Apex tests, so don't assert on the message.
            System.assertNotEquals(null, ex);

        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Expected an exception to be thrown for HTTP 500 response.'
        );

    }

    /*
     * ----------------------------------------------------------
     * Invalid Date Range
     * ----------------------------------------------------------
     */
    @IsTest
		static void testInvalidDateRange() {

    	Boolean exceptionThrown = false;

    	try {
        	TimeTrackerController.getTimeTrackerData(
            	Date.today(),
            	Date.today().addDays(-1),
            	null
        	);
    	} catch (Exception e) {
        	exceptionThrown = true;
    	}

    	System.assert(exceptionThrown);
	}

    /*
     * ----------------------------------------------------------
     * Null Dates (Controller Defaults)
     * ----------------------------------------------------------
     */
    @IsTest
    static void testNullDates() {

        Test.setMock(
            HttpCalloutMock.class,
            new EmptyMock()
        );

        Test.startTest();

        TimeTrackerResponse response =
            TimeTrackerController.getTimeTrackerData(
                null,
                null,
                null
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            response
        );

        System.assertEquals(
            7,
            response.headers.size()
        );

    }
    @IsTest
    static void testGetTimeByUserStorySuccess() {

        Test.setMock(
            HttpCalloutMock.class,
            new JiraSuccessMock()
        );

        Test.startTest();

        StoryTimeTrackerResponse response =
            TimeTrackerController.getTimeByUserStory(
                Date.newInstance(2026, 7, 20),
                Date.newInstance(2026, 7, 21),
                'PUL',
                'John'
            );

        Test.stopTest();

        System.assertEquals(
            2,
            response.headers.size()
        );

        System.assertEquals(
            1,
            response.stories.size()
        );

        System.assertEquals(
            'PUL-1',
            response.stories[0].issueKey
        );

        System.assertEquals(
            'Development',
            response.stories[0].issueSummary
        );

        System.assertEquals(
            3,
            response.stories[0].totalHours
        );

        System.assertEquals(
            2,
            response.stories[0].hoursByDate.get('2026-07-20')
        );

        System.assertEquals(
            1,
            response.stories[0].hoursByDate.get('2026-07-21')
        );

        System.assertEquals(
            3,
            response.grandTotal
        );

    }

    @IsTest
    static void testGetTimeByUserStoryEmptyResponse() {

        Test.setMock(
            HttpCalloutMock.class,
            new EmptyMock()
        );

        Test.startTest();

        StoryTimeTrackerResponse response =
            TimeTrackerController.getTimeByUserStory(
                Date.newInstance(2026, 7, 20),
                Date.newInstance(2026, 7, 21),
                'PUL',
                'John'
            );

        Test.stopTest();

        System.assertEquals(
            0,
            response.stories.size()
        );

        System.assertEquals(
            2,
            response.headers.size()
        );

        System.assertEquals(
            0,
            response.grandTotal
        );

    }

    @IsTest
    static void testGetTimeByUserStoryHttpError() {

        Test.setMock(
            HttpCalloutMock.class,
            new ErrorMock()
        );

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            TimeTrackerController.getTimeByUserStory(
                Date.today(),
                Date.today(),
                'PUL',
                'John'
            );

        } catch (Exception ex) {

            exceptionThrown = true;
            System.assertNotEquals(null, ex);

        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown
        );

    }

    @IsTest
    static void testGetTimeByUserStoryInvalidDateRange() {

        Boolean exceptionThrown = false;

        try {

            TimeTrackerController.getTimeByUserStory(
                Date.today(),
                Date.today().addDays(-1),
                'PUL',
                'John'
            );

        } catch (Exception ex) {

            exceptionThrown = true;

        }

        System.assertEquals(
            true,
            exceptionThrown
        );

    }

    @IsTest
    static void testGetTimeByUserStoryBlankResource() {

        Boolean exceptionThrown = false;

        try {

            TimeTrackerController.getTimeByUserStory(
                Date.today(),
                Date.today(),
                'PUL',
                ''
            );

        } catch (Exception ex) {

            exceptionThrown = true;

        }

        System.assertEquals(
            true,
            exceptionThrown
        );

    }

    @IsTest
    static void testGetTimeByUserStoryNullDates() {

        Test.setMock(
            HttpCalloutMock.class,
            new EmptyMock()
        );

        Test.startTest();

        StoryTimeTrackerResponse response =
            TimeTrackerController.getTimeByUserStory(
                null,
                null,
                'PUL',
                'John'
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            response
        );

        System.assertEquals(
            7,
            response.headers.size()
        );

    }

}