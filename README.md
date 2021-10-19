# AWS::SNS::Notification

Description of an AWS Simple Notification Service message.

[![CI](https://github.com/jonathanstowe/AWS-SNS-Notification/actions/workflows/main.yml/badge.svg)](https://github.com/jonathanstowe/AWS-SNS-Notification/actions/workflows/main.yml)

## Synopsis

```raku
use Cro::HTTP::Router;
use Cro::HTTP::Server;
use AWS::SNS::Notification;


my $app = route {
    post -> 'sns-message' {
        # The SNS message has a content-type of 'text/plain' so this will be raw JSON
        request-body -> $json {
            my $notification = AWS::SNS::Notification.from-json($json);
            # Check this is a valid notification
            if $notification.verify-signature {
               if $notification.is-notification {
                   # Do something with the $notification.message
                   # The format of which depends on the source - an S3 notification will be a JSON String for instance
               }
               else {
                   # This is subscribe or unsubscribe confirmation request
                   # so perform the confirmation
                   $notification.respond;
               }
            }
            else {
                bad-request 'text/plain', 'Fake notification';
            }
        }
    }
};

my Cro::Service $service = Cro::HTTP::Server.new(:host<127.0.0.1>, :port<7798>, application => $app);

$service.start;

react  { whenever signal(SIGINT) { $service.stop; exit; } }

```

## Description

This class describes an [AWS Simple Notification Service](https://aws.amazon.com/sns/) message that may be delivered by HTTPS or by a message queue or somesuch.

The class provides for parsing the JSON payload for the message, verifying the signature of the message against the signing key and responding if necessary to a Subscribe or Unsubscribe confirmation.

The actual message sent by the source application is accessed through the `.message` accessor - so for instance in the case of an S3 notification this will be a JSON string which will need to be decoded for further processing.

## Installation

Assuming you have a working rakudo installation you can install this with *zef* :

     zef install AWS::SNS::Notification

Or from a local clone of the distribution

     zef install AWS::SNS::Notification


## Support

If you have an feedback/suggestions/patches please send them via [Github](https://github.com/jonathanstowe/AWS-SNS-Notification/issues)

## Licence and Copyright

This library is free software.  Please see the [LICENCE](LICENCE) file in the distribution for details.

© Jonathan Stowe 2021

