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
--if theres no match in the left joins it returns NULLS
select 
	c.CustomerID,
	c.FirstName,
	o.OrderID,
	o.Sales
from Sales.Customers c
left join Sales.Orders o
on c.CustomerID = o.CustomerID

use SalesDB
--RIGHT JOIN 
--Returns alll rows in the right table and only the matching data in the left table.
--get all customers and their orders including orders without the matching customers
select 
	c.CustomerID,
	c.FirstName,
	o.OrderID,
	o.Sales
from Sales.Customers c
right join Sales.Orders o
on c.CustomerID = o.CustomerID

--solve the task without using the right join but only using the left join.
--that calls for switching sides
select 
	c.CustomerID,
	c.FirstName,
	o.OrderID,
	o.Sales
from Sales.Orders o
left join Sales.Customers c
on o.CustomerID = c.CustomerID

--FULL JOIN
--SQL returns everything. all the rows from all tables
--TASK: get all customees and all orders even if there is no match
select 
	c.CustomerID,
	c.FirstName,
	o.OrderID,
	o.Sales
from Sales.Customers c
full join Sales.Orders o
on c.CustomerID = o.CustomerID

--ADVANCED JOINS
--LEFT ANTI JOIN
--returns rows from the left table that have no match in the right
--Add a filter using the where clause to get rid of the matching data.
-- when the key is null that means theres no matching data
--TASK: Get all customers who havent placed any order.
select 
	*
from Sales.Customers c
left join Sales.Orders o
on c.CustomerID = o.CustomerID
where o.CustomerID is null

--same for the RIGHT ANTI JOIN
--switch sides 
--orders without customers
select 
	*
from Sales.Customers c
right join Sales.Orders o
on c.CustomerID = o.CustomerID
where c.CustomerID is null

--FULL ANTI JOIN 
--Returns only rows that dont match in both tables
--add two filters
--both keys in tables are empty
--can use the OR operator
--TASK: Find customers without orders and orders without customers
select 
	*
from Sales.Customers c
full join Sales.Orders o
on c.CustomerID = o.CustomerID
where o.CustomerID is null or c.CustomerID is null

--SQL TASK: Find all customers along with their orders but only for customers who have placed an order without using the inner join
--use the key IS NOT NULL

--CROSS JOIN
--GENERATE ALL POSSIBLE COMBINATIONS OF CUSTOMERS AND ORDERS
select 
	*
from Sales.Customers c
cross join Sales.Orders o

--MULTIPLE JOINS
--TASK: Retrieve a list of all orders along with the related customer, product and employee details for each order, display: 
--Order id, customer name, product name, sales, price, sales person name

select * from Sales.Customers;
select * from Sales.Employees;
select * from Sales.Orders;
select * from Sales.OrdersArchive;
select * from Sales.Products;

SELECT 
    o.OrderID,
    c.FirstName AS customerFirstname,
    p.Product AS productname,
    o.Sales,
    p.Price,
    e.FirstName AS employeeName
FROM Sales.Orders o
LEFT JOIN Sales.Customers c ON o.CustomerID = c.CustomerID
LEFT JOIN Sales.Products p ON o.ProductID = p.ProductID
LEFT JOIN Sales.Employees e ON o.SalesPersonID = e.EmployeeID
