#!/usr/bin/env raku

use Test;
use JSON::Fast;
use AWS::SNS::Notification;
use Test::Mock;
use Cro::HTTP::Client;
use URI;


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

    subtest {
        my $ua = mocked(Cro::HTTP::Client, returning => {
            get-body    => Promise.kept('OK')
        });
        my %args = from-json($*PROGRAM.parent.add('data/sconf.json').slurp);
        my $obj = AWS::SNS::Notification.new(%args, :$ua);
        my $subscribe-url = URI.new($obj.subscribe-url);
        my %q = $subscribe-url.query.Hash;
        $subscribe-url.query('');
        lives-ok { $obj.respond }, "respond";
        check-mock($ua, *.called('get-body', times => 1 , with => \($subscribe-url.Str, query => %q)));
    }, 'subscription confirmation';

    subtest {
        my $ua = mocked(Cro::HTTP::Client, returning => {
            get-body    => Promise.kept
        });
        my %args = from-json($*PROGRAM.parent.add('data/not.json').slurp);
        my $obj = AWS::SNS::Notification.new(%args, :$ua);
        lives-ok { $obj.respond }, "respond";
        check-mock($ua, *.called('get-body', times => 0 ));
    }, 'subscription confirmation';

done-testing;
# vim: ft=raku

