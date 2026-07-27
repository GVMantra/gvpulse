@IsTest(testFor=DemoClassOne.class)
private class DemoClassOneTest {

    @IsTest
    static void testConstructor() {
        Test.startTest();
        DemoClassOne obj = new DemoClassOne();
        Test.stopTest();

        System.assertNotEquals(null, obj, 'The object should be instantiated successfully.');
    }
}