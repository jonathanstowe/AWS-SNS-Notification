#!/usr/bin/env raku

use Test;
use AWS::SNS::Notification;

my @tests = (
    {
        name    => 'empty url',
        url     =>  Str,
        rc      => False,
    },
    {
        name    => 'not a complete url',
        url     =>  'ans?1234',
        rc      => False,
    },
    {
        name    => 'not an amazon',
        url     => 'http://example.com/cert.pem',
        rc      => False,
    },
    {
        name    => 'valid URL',
        url     => 'https://sns.eu-west-1.amazonaws.com/SimpleNotificationService-b95095beb82e8f6a046b3aafc7f4149a.pem',
        rc      => True,
    },
    {
        name    => 'valid CN URL',
        url     => 'https://sns.cn-north-1.amazonaws.com.cn/SimpleNotificationService-3242342098.pem',
        rc      => True,
    },
    {
        name    => 'my URL',
        url     => 'https://sns.us-east-1.amazonaws.com/SimpleNotificationService-7ff5318490ec183fbaddaa2a969abfda.pem',
        rc      => True,
    }
);

for @tests -> $test {
    my $a = AWS::SNS::Notification.new(signing-cert-url => $test<url>);
    is $a.validate-certificate-url, $test<rc>, $test<name>;
}


done-testing;
# vim: ft=raku
