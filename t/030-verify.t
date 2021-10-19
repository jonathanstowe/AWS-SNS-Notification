#!/usr/bin/env raku

use Test;
use JSON::Fast;
use AWS::SNS::Notification;
use Test::Mock;
use Cro::HTTP::Client;

my Str $signing-certificate = $*PROGRAM.parent.add('data/SimpleNotificationService-7ff5318490ec183fbaddaa2a969abfda.pem').slurp;

my $ua = mocked(Cro::HTTP::Client, returning => {
    get-body    => Promise.kept($signing-certificate)
});
my @tests = (
    {
        name => 'Notification',
        message => 'not.json',
    },
    {
        name    =>  'Subscription',
        message =>  'sconf.json',
    }
);

for @tests  -> $test {
    subtest {
        my %args = from-json($*PROGRAM.parent.add("data/$test<message>").slurp);
        my $obj = AWS::SNS::Notification.new(%args, :$ua);
        ok $obj.verify-signature, 'verify-signature (valid URL)';
        %args<SigningCertURL> = 'http://example.com/whatever';
        $obj = AWS::SNS::Notification.new(%args, :$ua);
        ok !$obj.verify-signature, 'verify-signature (invalid URL)';
        ok $obj.verify-signature(:!validate-url) , 'verify-signature (invalid URL - but no validate-url)';
    }, $test<name>;
}
done-testing;
# vim: ft=raku

