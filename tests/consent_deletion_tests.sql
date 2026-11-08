\set ON_ERROR_STOP 0
insert into auth.users(id) values ('eeeeeeee-0000-0000-0000-000000000005');
set role authenticated; set request.jwt.claim.sub='eeeeeeee-0000-0000-0000-000000000005';
\echo '== T1 no consent yet -> f'
select has_required_consent();
\echo '== T2 direct insert blocked (expect error)'
insert into consents(user_id,purpose,granted,notice_version) values (auth.uid(),'privacy_notice',true,'v1');
\echo '== T3 via function: both consents -> t'
select record_consent('privacy_notice',true,'v1'); select record_consent('age_18plus',true,'v1'); select has_required_consent();
\echo '== T4 withdraw privacy -> f, history kept (3 rows)'
select record_consent('privacy_notice',false,'v1'); select has_required_consent(); select count(*) from consents;
\echo '== T5 bad purpose / version rejected (expect 2 errors)'
select record_consent('sell_my_data',true,'v1'); select record_consent('marketing',true,'v1; drop table x');
\echo '== T6 cannot edit/delete history (expect errors)'
update consents set granted=true; delete from consents;
\echo '== T7 anon cannot call record_consent (expect error)'
reset role; set role anon; select record_consent('marketing',true,'v1');
\echo '== T8 deletion request: 48h notice, only one pending'
reset role; set role authenticated; set request.jwt.claim.sub='eeeeeeee-0000-0000-0000-000000000005';
select (request_deletion() - now()) between interval '47 hours' and interval '49 hours' as ok48; select request_deletion() is not null; select count(*) from deletion_requests;
select cancel_deletion(); select status from deletion_requests;
