---Joins and Set Operators
--Combining data rows and columns
--TASK: NO JOIN
--Retrieve all data from customers and orders in two different results
select * from Sales.Customers;
select * from Sales.Orders;

--INNER JOIN
--Returns only matching rows from both tables
--Task: Retrieve all customers along with their orders but only those who have placed an order.
select 
	c.CustomerID,
	c.FirstName,
	o.OrderID,
	o.Sales
from Sales.Customers c
inner join Sales.Orders o
on c.CustomerID = o.CustomerID

--LEFT JOIN
--Returns all rows from LEFT table and only THE Matching from the RIGHT
--Order os tables is important to follow and note
--TASK: Get all customers along with their orders including those without orders.
select 
	c.CustomerID,
	c.FirstName,
	o.OrderID,
	o.Sales
from Sales.Customers c
left join Sales.Orders o
on c.CustomerID = o.CustomerID
