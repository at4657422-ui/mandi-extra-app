\set ON_ERROR_STOP 0
insert into auth.users(id) values ('aaaaaaaa-0000-0000-0000-000000000001'),('dddddddd-0000-0000-0000-000000000004');
insert into user_roles(user_id,role,status) values ('dddddddd-0000-0000-0000-000000000004','admin_ops','approved');
\echo '== T1 normal user cannot write (expect error)'
set role authenticated; set request.jwt.claim.sub='aaaaaaaa-0000-0000-0000-000000000001';
insert into banners(placement,image_path,is_active) values ('home','a/b.jpg',true);
\echo '== T2 admin WITHOUT 2FA cannot write (expect error)'
set request.jwt.claim.sub='dddddddd-0000-0000-0000-000000000004'; set request.jwt.claims='{"sub":"dddddddd-0000-0000-0000-000000000004","aal":"aal1"}';
insert into banners(placement,image_path,is_active) values ('home','a/b.jpg',true);
\echo '== T3 admin WITH 2FA can write'
set request.jwt.claims='{"sub":"dddddddd-0000-0000-0000-000000000004","aal":"aal2"}';
insert into banners(placement,image_path,link_url,is_active) values ('home','a/b.jpg','https://example.com/x',true);
insert into site_content(key,body,is_published) values ('guide:commission','test',true);
insert into site_media(kind,title,storage_path,placement,is_published) values ('video','t','v/a.mp4','guide:commission',true), ('video','draft','v/b.mp4','guide:commission',false);
\echo '== T4 javascript: link blocked, path traversal blocked (expect 2 errors)'
insert into banners(placement,image_path,link_url) values ('home','a/b.jpg','javascript:alert(1)');
insert into site_media(kind,title,storage_path,placement) values ('image','x','../../etc/passwd','home');
\echo '== T5 anon sees only published (expect 1 media, 1 banner, 1 content)'
reset role; set role anon; reset request.jwt.claims; reset request.jwt.claim.sub;
select (select count(*) from site_media) m,(select count(*) from banners) b,(select count(*) from site_content) c;
\echo '== T6 anon cannot write (expect error)'
insert into site_content(key,body) values ('x','y');
\echo '== T7 audit rows written'
reset role; select count(*) from audit_logs where target_table in ('banners','site_media','site_content');
