#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { GrafanaDuckdbStack } from '../lib/grafana-duckdb-stack';

const app = new cdk.App();

new GrafanaDuckdbStack(app, 'GrafanaDuckdbStack', {

});
