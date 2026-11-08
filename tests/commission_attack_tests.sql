\set ON_ERROR_STOP 0
\pset pager off
-- setup as superuser
insert into auth.users(id) values
 ('aaaaaaaa-0000-0000-0000-000000000001'),('bbbbbbbb-0000-0000-0000-000000000002'),('cccccccc-0000-0000-0000-000000000003');
insert into public.seller_profiles(user_id,business_name,state) values ('bbbbbbbb-0000-0000-0000-000000000002','Seller B','Bihar');
update public.products set status='active' where false;
insert into public.products(seller_id,category_id,title,price_paise,status)
 select (select id from seller_profiles limit 1),(select id from categories limit 1),'Cement 50kg',10000000,'active';
\echo '=== T1: ratio 2% of Rs100000 (10000000 paise)'
set role authenticated; set request.jwt.claim.sub='aaaaaaaa-0000-0000-0000-000000000001';
select public.create_order((select id from products limit 1), 1, 'key-12345678') as oid \gset
select deal_value_paise, commission_percent, commission_paise, buyer_commission_paise, seller_commission_paise, seller_payout_paise, status from orders where id=:'oid';
\echo '=== T2: same idempotency key -> same order id (expect t)'
select public.create_order((select id from products limit 1), 1, 'key-12345678') = :'oid'::uuid as same;
\echo '=== T3: direct INSERT into orders (expect permission error)'
insert into orders(buyer_id,seller_id,product_id,quantity,unit_price_paise,commission_percent,commission_paise) values ('aaaaaaaa-0000-0000-0000-000000000001',(select id from seller_profiles limit 1),(select id from products limit 1),1,1,0,0);
\echo '=== T4: tamper commission via update (expect error)'
update orders set commission_paise=1 where id=:'oid';
\echo '=== T5: seller buys own product (expect error)'
reset role; set role authenticated; set request.jwt.claim.sub='bbbbbbbb-0000-0000-0000-000000000002';
select public.create_order((select id from products limit 1), 1, 'key-selfbuy-1');
\echo '=== T6: wrong person submits UTR (expect error)'
set request.jwt.claim.sub='cccccccc-0000-0000-0000-000000000003';
insert into payments(order_id,amount_paise,utr) values (:'oid',1,'123456789012');
\echo '=== T7: buyer submits UTR with fake amount 1 -> forced to full commission'
set request.jwt.claim.sub='aaaaaaaa-0000-0000-0000-000000000001';
insert into payments(order_id,amount_paise,utr) values (:'oid',1,'123456789012');
select amount_paise, status from payments;
select status from orders where id=:'oid';
\echo '=== T8: second payment on same order (expect error)'
insert into payments(order_id,amount_paise,utr) values (:'oid',1,'999999999999');
\echo '=== T9: bad UTR format (expect error)'
reset role; update payments set status='rejected'; set role authenticated; set request.jwt.claim.sub='aaaaaaaa-0000-0000-0000-000000000001';
insert into payments(order_id,amount_paise,utr) values (:'oid',1,'12AB');
\echo '=== T10: buyer cannot verify own payment (expect 0 rows updated)'
insert into payments(order_id,amount_paise,utr) values (:'oid',1,'555555555555');
update payments set status='verified';
\echo '=== T11: odd paise rounding (Rs 333.33 deal)'
reset role;
select * from compute_commission(33333, 2.0), compute_commission(33333, 1.0) c2;
\echo '=== T12: worker profile = 1%, and seller cannot change fee_profile'
alter table seller_profiles disable trigger seller_fee_profile_guard;
update seller_profiles set fee_profile='worker';
set role authenticated; set request.jwt.claim.sub='cccccccc-0000-0000-0000-000000000003';
select public.create_order((select id from products limit 1), 1, 'key-worker-123') as ow \gset
reset role; select commission_percent, commission_paise from orders where id=:'ow';
update seller_profiles set fee_profile='standard'; alter table seller_profiles enable trigger seller_fee_profile_guard;
set role authenticated; set request.jwt.claim.sub='bbbbbbbb-0000-0000-0000-000000000002';
update seller_profiles set fee_profile='worker' where user_id='bbbbbbbb-0000-0000-0000-000000000002';
reset role;
\echo '=== T13: setting > 2% cannot be used (cap)'
update app_settings set value='9' where key='fee_percent_standard';
set role authenticated; set request.jwt.claim.sub='cccccccc-0000-0000-0000-000000000003';
select public.create_order((select id from products limit 1), 1, 'key-cap-12345') as o2 \gset
reset role; select commission_percent from orders where id=:'o2';
update app_settings set value='2.0' where key='fee_percent_standard';
\echo '=== T14: full happy path: verify -> dispatch -> complete; wrong role steps fail'
update payments set status='verified' where utr='555555555555';
select status from orders where id=:'oid';
set role authenticated; set request.jwt.claim.sub='aaaaaaaa-0000-0000-0000-000000000001';
select advance_order(:'oid','completed');
set request.jwt.claim.sub='bbbbbbbb-0000-0000-0000-000000000002';
select advance_order(:'oid','dispatched');
select advance_order(:'oid','completed');
set request.jwt.claim.sub='aaaaaaaa-0000-0000-0000-000000000001';
select advance_order(:'oid','completed');
reset role; select status from orders where id=:'oid';
\echo '=== T15: expiry'
update orders set expires_at=now()-interval '1 hour' where id=:'o2';
select expire_unpaid_orders();
select status from orders where id=:'o2';
\echo '=== T16: refund record immutable'
insert into refunds(order_id,amount_paise,refund_utr,reason,created_by) values (:'oid',1,'111111111111','test',(select id from profiles limit 1));
update refunds set amount_paise=5;
