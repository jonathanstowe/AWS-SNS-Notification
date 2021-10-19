#!/usr/bin/env raku

use Test;
use AWS::SNS::Notification;
use JSON::Fast;

my @tests = {
                description => "Plain notification",
                data        => "not.json",
                is-notification => True,
            },
            {
                description => "Subscription",
                data        => "sconf.json",
                is-notification => False,
            };

sub check-attributes($obj, $args ) {
    my %aliases = (:Message("message"), :MessageId("message-id"), :Signature("signature"), :SignatureVersion("signature-version"), :SigningCertURL("signing-cert-url"), :Subject("subject"), :SubscribeURL("subscribe-url"), :Timestamp("timestamp"), :Token("token"), :TopicArn("topic-arn"), :Type("type"));

    for %aliases.kv -> $json-name, $attr-name {
        if $args{$json-name}.defined {
            is $obj."$attr-name"(), $args{$json-name}, "Value of '$json-name' is correct";
        }
    }

}

for @tests -> $test {
    subtest {
        my $json = $*PROGRAM.parent.add("data", $test<data>).slurp;
        my $args = from-json($json);
        my $obj;
        lives-ok { $obj = AWS::SNS::Notification.from-json($json) }, "create object from json";
        is $obj.is-notification, $test<is-notification>, "and is-notification correct";
        check-attributes($obj, $args);
        lives-ok { $obj = AWS::SNS::Notification.new($args) }, "create object from hash";
        is $obj.is-notification, $test<is-notification>, "and is-notification correct";
        check-attributes($obj, $args);
    }, $test<description>;
}

done-testing;
# vim: ft=raku
