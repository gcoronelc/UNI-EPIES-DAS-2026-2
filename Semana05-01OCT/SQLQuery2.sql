
declare @idventa int;
set @idventa = 7;
select * from VENTA where IDVENTA=@idventa;
select * from DETALLE_VENTA where IDVENTA=@idventa;
select * from PAGO where IDVENTA=@idventa;
go

select * from TIPO_PAGO;
go


